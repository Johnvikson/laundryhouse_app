import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;

  // ─── Auth ────────────────────────────────────────────────────────────────

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String role = 'customer',
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'phone': phone, 'role': role},
    );
    if (res.user != null && role == 'customer') {
      // Upsert customer profile
      await _client.from('customer_profiles').upsert({
        'user_id': res.user!.id,
        'name': name,
        'phone': phone,
        'email': email,
      });
    }
    return res;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => _client.auth.signOut();

  static User? get currentUser => _client.auth.currentUser;

  static Session? get currentSession => _client.auth.currentSession;

  // ─── Customer Profile ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getCustomerProfile(String userId) async {
    final res = await _client
        .from('customer_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }

  static Future<void> updateCustomerProfile({
    required String userId,
    required String name,
    required String phone,
    String? address,
  }) async {
    await _client.from('customer_profiles').update({
      'name': name,
      'phone': phone,
      if (address != null) 'default_address': address,
    }).eq('user_id', userId);
  }

  // ─── Price Items ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPriceItems() async {
    final res = await _client
        .from('price_list')
        .select()
        .order('category')
        .order('service_type');
    return List<Map<String, dynamic>>.from(res);
  }

  // ─── Orders ──────────────────────────────────────────────────────────────

  static String generateOrderCode() {
    final ts = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    final rand = (DateTime.now().microsecond % 1000)
        .toRadixString(36)
        .toUpperCase()
        .padLeft(3, '0');
    return 'CLH-$ts$rand';
  }

  static Future<Map<String, dynamic>> createOrder(
      Map<String, dynamic> order) async {
    final res = await _client
        .from('orders')
        .insert(order)
        .select()
        .single();
    return res;
  }

  static Future<void> createOrderItems(
      String orderId, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      item['order_id'] = orderId;
    }
    await _client.from('order_items').insert(items);
  }

  static Future<List<Map<String, dynamic>>> getCustomerOrders(
      String userId) async {
    // customer_id references customer_profiles.id, not auth.users.id
    // so first get the profile id
    final profile = await getCustomerProfile(userId);
    if (profile == null) return [];
    final profileId = profile['id'] as String;
    final res = await _client
        .from('orders')
        .select('*, order_items(*), rider_profiles(name, phone)')
        .eq('customer_id', profileId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getCustomerOrdersByCode(
      String customerCode) async {
    final res = await _client
        .from('orders')
        .select('*, order_items(*), rider_profiles(name, phone)')
        .eq('customer_code', customerCode)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // ─── Rider Profile ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getRiderProfile(String userId) async {
    final res = await _client
        .from('rider_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }

  static Future<void> updateRiderAvailability(
      String riderId, bool isAvailable) async {
    await _client
        .from('rider_profiles')
        .update({'is_available': isAvailable})
        .eq('id', riderId);
  }

  // ─── Rider Orders ────────────────────────────────────────────────────────

  // Available pickup orders: paid online orders waiting for a rider
  static Future<List<Map<String, dynamic>>> getAvailablePickupOrders() async {
    final res = await _client
        .from('orders')
        .select('*, order_items(category, quantity)')
        .eq('order_type', 'online')
        .eq('payment_status', 'paid')
        .isFilter('rider_id', null)
        .inFilter('delivery_status', ['pending', 'waiting_for_rider'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Available delivery jobs: completed orders ready for delivery without a rider
  static Future<List<Map<String, dynamic>>> getAvailableDeliveryJobs() async {
    final res = await _client
        .from('orders')
        .select('*, order_items(category, quantity)')
        .eq('status', 'completed')
        .eq('delivery_status', 'ready_for_delivery')
        .isFilter('rider_id', null)
        .not('delivery_address', 'is', null)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Rider's active pickup orders
  static Future<List<Map<String, dynamic>>> getRiderPickupOrders(
      String riderId) async {
    final res = await _client
        .from('orders')
        .select('*, order_items(category, quantity)')
        .eq('rider_id', riderId)
        .inFilter('delivery_status', ['rider_accepted', 'rider_at_location', 'picked_up'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Rider's active delivery orders
  static Future<List<Map<String, dynamic>>> getRiderDeliveryOrders(
      String riderId) async {
    final res = await _client
        .from('orders')
        .select('*, order_items(category, quantity)')
        .eq('rider_id', riderId)
        .inFilter('delivery_status', ['delivery_accepted', 'out_for_delivery'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  // Rider's completed orders for earnings calculation
  static Future<List<Map<String, dynamic>>> getRiderCompletedOrders(
      String riderId) async {
    final res = await _client
        .from('orders')
        .select('*, order_items(category, quantity)')
        .eq('rider_id', riderId)
        .inFilter('delivery_status', ['delivered_processing', 'completed'])
        .order('delivered_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getRiderActiveOrders(
      String riderId) async {
    return getRiderPickupOrders(riderId);
  }

  static Future<void> acceptPickup(String orderId, String riderId) async {
    await _client.from('orders').update({
      'rider_id': riderId,
      'delivery_status': 'rider_accepted',
    }).eq('id', orderId).isFilter('rider_id', null);
  }

  static Future<void> acceptDeliveryJob(
      String orderId, String riderId, double fee) async {
    await _client.from('orders').update({
      'rider_id': riderId,
      'delivery_status': 'delivery_accepted',
      'delivery_fee': fee,
    }).eq('id', orderId).isFilter('rider_id', null);
  }

  static Future<void> acceptDelivery(
      String orderId, String riderId) async {
    await _client.from('orders').update({
      'rider_id': riderId,
      'delivery_status': 'delivery_accepted',
    }).eq('id', orderId);
  }

  static Future<void> updateDeliveryStatus(
      String orderId, String deliveryStatus) async {
    final Map<String, dynamic> updates = {'delivery_status': deliveryStatus};
    if (deliveryStatus == 'rider_at_location') {
      updates['rider_at_location_at'] = DateTime.now().toIso8601String();
    } else if (deliveryStatus == 'picked_up') {
      updates['picked_up_at'] = DateTime.now().toIso8601String();
    } else if (deliveryStatus == 'delivered_processing') {
      updates['delivered_at'] = DateTime.now().toIso8601String();
    } else if (deliveryStatus == 'out_for_delivery') {
      updates['picked_up_at'] = DateTime.now().toIso8601String();
    } else if (deliveryStatus == 'completed') {
      updates['delivered_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('orders').update(updates).eq('id', orderId);
  }

  static Future<void> completeDelivery(String orderId) async {
    await _client.from('orders').update({
      'delivery_status': 'completed',
      'delivered_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }
}
