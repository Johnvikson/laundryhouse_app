import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';

const _kPrimary = Color(0xFF9333EA);
const _kCyan = Color(0xFF0891B2);
const _kGreen = Color(0xFF16A34A);
const _kLaundryPhone = '08124201935';

class CustomerTrackScreen extends StatefulWidget {
  const CustomerTrackScreen({super.key});

  @override
  State<CustomerTrackScreen> createState() => _CustomerTrackScreenState();
}

class _CustomerTrackScreenState extends State<CustomerTrackScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  RealtimeChannel? _realtimeChannel;
  String? _profileId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final user = context.read<UserProvider>();
    if (user.userId == null) return;
    try {
      final orders = await SupabaseService.getCustomerOrders(user.userId!);
      if (mounted) {
        setState(() { _orders = orders; _loading = false; });
        // Subscribe to realtime after we have the profile id
        if (_realtimeChannel == null) {
          final profile = await SupabaseService.getCustomerProfile(user.userId!);
          if (profile != null) {
            _profileId = profile['id'] as String;
            _subscribeToOrderUpdates();
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToOrderUpdates() {
    if (_profileId == null) return;
    _realtimeChannel = SupabaseService.client
        .channel('customer-orders-$_profileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (payload) async {
            final newData = payload.newRecord;
            // Only handle updates to this customer's orders
            if (newData['customer_id'] != _profileId) return;
            final ds = newData['delivery_status'] as String? ?? '';
            final msg = _deliveryStatusMessage(ds);
            if (msg.isNotEmpty) {
              await NotificationService.showOrderUpdate(
                title: 'LaundryHouse – Order Update',
                body: msg,
              );
            }
            // Refresh the order list
            if (mounted) _loadOrders();
          },
        )
        .subscribe();
  }

  String _deliveryStatusMessage(String ds) {
    switch (ds) {
      case 'waiting_for_rider': return 'Looking for a rider for your order...';
      case 'rider_accepted':    return 'A rider is on the way to pick up your laundry!';
      case 'rider_at_location': return 'Your rider has arrived at your location';
      case 'picked_up':         return 'Your laundry has been picked up';
      case 'delivered_processing': return 'Your laundry is being cleaned and processed';
      case 'ready_for_delivery':   return 'Your order is ready for delivery';
      case 'delivery_accepted':    return 'A delivery rider has been assigned to your order';
      case 'out_for_delivery':     return 'Your order is out for delivery!';
      case 'completed':            return 'Your order has been delivered!';
      default: return '';
    }
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    context.read<UserProvider>().clearUser();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _retryPayment(Map<String, dynamic> order) async {
    final user = context.read<UserProvider>();
    final pubKey = dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ?? '';
    final ref = 'LH_${DateTime.now().millisecondsSinceEpoch}';
    final amount = (order['total'] as num?)?.toDouble() ?? 0.0;
    final url = Uri.parse(
      'https://checkout.flutterwave.com/v3/hosted/pay'
      '?public_key=$pubKey&tx_ref=$ref'
      '&amount=${amount.toStringAsFixed(2)}&currency=NGN'
      '&redirect_url=https://viovlxpsrjpobysmydtq.supabase.co/functions/v1/flutterwave-webhook'
      '&customer[email]=${Uri.encodeComponent(user.email ?? '')}'
      '&customer[name]=${Uri.encodeComponent(user.name ?? '')}'
      '&customizations[title]=LaundryHouse&customizations[description]=Order ${order['order_code']}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open payment page')),
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FF),
      body: Column(
        children: [
          _buildHeader(user),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(_kPrimary),
                    ),
                  )
                : _orders.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        color: _kPrimary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _orders.length,
                          itemBuilder: (_, i) => _buildOrderCard(_orders[i]),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader(UserProvider user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/icon.png', width: 40, height: 40, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A1A2E))),
                    Text(user.name ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: const Text('New Order'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 22),
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No Orders Yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text("You haven't placed any orders yet.", style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: const Text('Place Your First Order'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final paymentStatus = order['payment_status'] as String? ?? 'pending';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final expressCharge = (order['express_charge'] as num?)?.toDouble() ?? 0.0;
    final orderCode = order['order_code'] as String? ?? '';
    final createdAt = order['created_at'] as String? ?? '';
    final orderType = order['order_type'] as String? ?? '';
    final rider = order['rider_profiles'];
    final items = order['order_items'] as List<dynamic>? ?? [];
    final pickupAddress = order['pickup_address'] as String?;
    final deliveryAddress = order['delivery_address'] as String?;
    final readyDate = order['ready_date'] as String?;

    String dateStr = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      dateStr = DateFormat("MMM d, yyyy 'at' h:mm a").format(dt);
    } catch (_) {}

    final statusInfo = _getDeliveryStatusInfo(order);
    final isPaid = paymentStatus == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F5FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _statusIcon(status),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E))),
                      Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusBadge(status),
                    const SizedBox(height: 4),
                    _paymentBadge(paymentStatus),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live delivery status tracker (online orders)
                if (orderType == 'online') ...[
                  _buildStatusTracker(order, statusInfo, isPaid, rider, deliveryAddress),
                  const SizedBox(height: 14),
                ],

                // Order items
                const Text('Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                ...items.map((item) {
                  final cat = item['category'] as String? ?? '';
                  final svc = item['service_type'] as String? ?? '';
                  final qty = item['quantity'] as int? ?? 0;
                  final sub = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('$cat - $svc × $qty', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                        Text('₦${sub.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),

                // Addresses
                if (pickupAddress != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pickup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(pickupAddress, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (deliveryAddress != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(deliveryAddress, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            if (readyDate != null)
                              Text(
                                'Ready by: ${_fmtDate(readyDate)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                const Divider(),
                const SizedBox(height: 6),

                // Total & pay button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('₦${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                        if (expressCharge > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('(Express)', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ),
                      ],
                    ),
                    if (paymentStatus != 'paid')
                      ElevatedButton.icon(
                        onPressed: () => _retryPayment(order),
                        icon: const Icon(Icons.credit_card, size: 16),
                        label: const Text('Pay Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTracker(
    Map<String, dynamic> order,
    _StatusInfo info,
    bool isPaid,
    dynamic rider,
    String? deliveryAddress,
  ) {
    final deliveryStatus = order['delivery_status'] as String? ?? 'pending';
    final isPastPickup = ['delivered_processing', 'completed', 'ready_for_delivery', 'delivery_accepted', 'out_for_delivery']
        .contains(deliveryStatus);
    final isComplete = order['status'] == 'completed' && deliveryStatus == 'completed';
    final showPickupSteps = isPaid &&
        !['pending', 'waiting_for_rider'].contains(deliveryStatus);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isPaid
            ? LinearGradient(
                colors: [_kPrimary.withValues(alpha: 0.08), _kPrimary.withValues(alpha: 0.03), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(colors: [Colors.grey.shade50, Colors.grey.shade50]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid ? _kPrimary.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(info.icon, size: 18, color: info.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(info.label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: info.color)),
                        if (isPaid && !isComplete)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _PulseIcon(color: _kPrimary),
                          ),
                      ],
                    ),
                    Text(info.description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),

          // Pickup steps
          if (showPickupSteps) ...[
            const SizedBox(height: 14),
            Text('Pickup Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
            const SizedBox(height: 8),
            ..._pickupSteps(order).asMap().entries.map((e) {
              final idx = e.key;
              final step = e.value;
              final isLast = idx == _pickupSteps(order).length - 1;
              return _buildStep(step['label'] as String, step['status'] as String, isLast: isLast);
            }),
          ],

          // Delivery steps
          if (deliveryAddress != null && isPastPickup) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 6),
            Text('Delivery Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
            const SizedBox(height: 8),
            ..._deliverySteps(deliveryStatus).asMap().entries.map((e) {
              final idx = e.key;
              final step = e.value;
              final isLast = idx == _deliverySteps(deliveryStatus).length - 1;
              return _buildStep(step['label'] as String, step['status'] as String, isLast: isLast);
            }),
          ],

          // Contact info
          if (isPaid) ...[
            const SizedBox(height: 12),
            _buildContactInfo(order, rider, isComplete, isPastPickup),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(String label, String status, {required bool isLast}) {
    final isDone = status == 'completed';
    final isCurrent = status == 'current';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? _kGreen : isCurrent ? _kPrimary : Colors.grey[200],
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Icon(Icons.circle, size: 8, color: isCurrent ? Colors.white : Colors.grey[400]),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 28, color: isDone ? _kGreen : Colors.grey[200]),
          ],
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: isDone ? _kGreen : isCurrent ? _kPrimary : Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo(
    Map<String, dynamic> order,
    dynamic rider,
    bool isComplete,
    bool isPastPickup,
  ) {
    final showRider = rider != null && order['rider_id'] != null && !isComplete && !isPastPickup;
    final name = showRider ? (rider['name'] as String? ?? 'Rider') : 'LaundryHouse';
    final phone = showRider ? (rider['phone'] as String? ?? '') : _kLaundryPhone;
    final hasDelivery = order['delivery_address'] != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: showRider
                ? const Icon(Icons.person, size: 20, color: _kPrimary)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: Image.asset('assets/images/icon.png', fit: BoxFit.cover),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showRider ? 'Your Rider' : (hasDelivery ? 'Contact LaundryHouse' : 'Pickup Location'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (!showRider && !hasDelivery)
                  Text('4, Oloke-Meji Road, Abeokuta', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _callPhone(phone),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, size: 18, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _pickupSteps(Map<String, dynamic> order) {
    final ds = order['delivery_status'] as String? ?? 'pending';
    int current = -1;
    if (['rider_accepted'].contains(ds)) { current = 0; }
    else if (['rider_at_location'].contains(ds)) { current = 1; }
    else if (['picked_up'].contains(ds)) { current = 2; }
    else if (['delivered_processing', 'completed', 'ready_for_delivery', 'delivery_accepted', 'out_for_delivery'].contains(ds)) { current = 3; }

    final labels = [
      'Order Accepted by Rider',
      'Rider at your location',
      'Rider picked up your order',
      'Delivered & Processing',
      'Ready for delivery',
    ];

    return labels.asMap().entries.map((e) {
      final idx = e.key;
      String status;
      if (idx < current) { status = 'completed'; }
      else if (idx == current) { status = 'current'; }
      else { status = 'upcoming'; }
      return {'label': e.value, 'status': status};
    }).toList();
  }

  List<Map<String, String>> _deliverySteps(String ds) {
    final steps = [
      {'id': 'ready_for_delivery', 'label': 'Order ready for delivery'},
      {'id': 'delivery_accepted', 'label': 'Delivery rider assigned'},
      {'id': 'out_for_delivery', 'label': 'Out for delivery'},
      {'id': 'completed', 'label': 'Delivered to you'},
    ];
    final order = ['ready_for_delivery', 'delivery_accepted', 'out_for_delivery', 'completed'];
    final currentIdx = order.indexOf(ds);
    return steps.asMap().entries.map((e) {
      final idx = e.key;
      String status;
      if (currentIdx > idx) { status = 'completed'; }
      else if (currentIdx == idx) { status = 'current'; }
      else { status = 'upcoming'; }
      return {'label': e.value['label']!, 'status': status};
    }).toList();
  }

  _StatusInfo _getDeliveryStatusInfo(Map<String, dynamic> order) {
    final ds = order['delivery_status'] as String? ?? 'pending';
    final ps = order['payment_status'] as String? ?? 'pending';

    if (ps == 'paid' && ds == 'pending') {
      return _StatusInfo('Waiting for Rider', Icons.delivery_dining, Colors.orange[700]!, 'Looking for a rider to pick up your order');
    }

    switch (ds) {
      case 'waiting_for_rider': return _StatusInfo('Waiting for Rider', Icons.delivery_dining, Colors.orange[700]!, 'Looking for a rider to pick up your order');
      case 'rider_accepted': return _StatusInfo('Rider Accepted', Icons.check_circle_outline, Colors.blue[600]!, 'A rider is on the way to pick up your laundry');
      case 'rider_at_location': return _StatusInfo('Rider at Location', Icons.navigation, Colors.purple[600]!, 'Rider has arrived at your location');
      case 'picked_up': return _StatusInfo('Order Picked Up', Icons.inventory_2_outlined, Colors.orange[700]!, 'Your laundry is on the way to the store');
      case 'delivered_processing': return _StatusInfo('Delivered & Processing', Icons.local_laundry_service, _kPrimary, 'Your laundry is being cleaned and processed');
      case 'ready_for_delivery': return _StatusInfo('Ready for Delivery', Icons.local_shipping_outlined, Colors.blue[600]!, 'Your order is ready and waiting for delivery');
      case 'delivery_accepted': return _StatusInfo('Delivery Rider Assigned', Icons.delivery_dining, Colors.purple[600]!, 'A rider has accepted to deliver your order');
      case 'out_for_delivery': return _StatusInfo('Out for Delivery', Icons.local_shipping, Colors.orange[700]!, 'Your order is on the way to you');
      case 'completed': return _StatusInfo('Order Completed', Icons.check_circle, _kGreen, order['delivery_address'] != null ? 'Your order has been delivered!' : 'Ready for pickup at store');
      default: return _StatusInfo('Payment Pending', Icons.schedule, Colors.grey[600]!, 'Complete payment to proceed');
    }
  }

  Widget _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return const Icon(Icons.check_circle, color: _kGreen, size: 22);
      case 'ready': return const Icon(Icons.local_shipping_outlined, color: Color(0xFF0891B2), size: 22);
      case 'in_progress': return const Icon(Icons.local_laundry_service, color: Colors.orange, size: 22);
      default: return Icon(Icons.schedule, color: Colors.grey[500], size: 22);
    }
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed': color = _kGreen; break;
      case 'ready': color = _kCyan; break;
      case 'in_progress': color = Colors.orange; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _paymentBadge(String status) {
    final isPaid = status == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isPaid ? _kGreen : Colors.red).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Unpaid',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPaid ? _kGreen : Colors.red),
      ),
    );
  }

  String _fmtDate(String iso) {
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal()); } catch (_) { return iso; }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_outlined, 'Order', onTap: () => Navigator.pushReplacementNamed(context, '/home')),
              _navItem(Icons.receipt_long, 'My Orders', selected: true),
              _navItem(Icons.person_outline, 'Profile', onTap: () => Navigator.pushReplacementNamed(context, '/profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {bool selected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: selected ? _kPrimary : Colors.grey[500]),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 11, color: selected ? _kPrimary : Colors.grey[500], fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;
  final String description;
  const _StatusInfo(this.label, this.icon, this.color, this.description);
}

class _PulseIcon extends StatefulWidget {
  final Color color;
  const _PulseIcon({required this.color});
  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Icon(Icons.auto_awesome, size: 14, color: widget.color),
    );
  }
}
