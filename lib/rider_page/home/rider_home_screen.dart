import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/notifications_sheet.dart';

const _kPrimary = Color(0xFF9333EA);
const _kCyan = Color(0xFF0891B2);
const _kGreen = Color(0xFF16A34A);
const _kPickupFee = 1200.0;

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _riderProfile;
  List<Map<String, dynamic>> _availablePickups = [];
  List<Map<String, dynamic>> _availableDeliveries = [];
  List<Map<String, dynamic>> _myPickupOrders = [];
  List<Map<String, dynamic>> _myDeliveryOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];
  bool _loading = true;
  bool _updatingStatus = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = context.read<UserProvider>();
    if (user.userId == null) return;
    try {
      final profile = await SupabaseService.getRiderProfile(user.userId!);
      final pickups = await SupabaseService.getAvailablePickupOrders();
      final deliveries = await SupabaseService.getAvailableDeliveryJobs();
      List<Map<String, dynamic>> myPickups = [];
      List<Map<String, dynamic>> myDeliveries = [];
      List<Map<String, dynamic>> completed = [];
      if (profile != null) {
        myPickups = await SupabaseService.getRiderPickupOrders(profile['id']);
        myDeliveries = await SupabaseService.getRiderDeliveryOrders(profile['id']);
        completed = await SupabaseService.getRiderCompletedOrders(profile['id']);
      }
      if (mounted) {
        setState(() {
          _riderProfile = profile;
          _availablePickups = pickups;
          _availableDeliveries = deliveries;
          _myPickupOrders = myPickups;
          _myDeliveryOrders = myDeliveries;
          _completedOrders = completed;
          _loading = false;
        });
        // Start realtime subscription once profile is loaded
        if (profile != null && _realtimeChannel == null) {
          _subscribeToOrders(profile['id'] as String);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToOrders(String riderId) {
    _realtimeChannel = SupabaseService.client
        .channel('rider-orders-$riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) async {
            final newData = payload.newRecord;
            final isPaid = newData['payment_status'] == 'paid';
            final isOnline = newData['order_type'] == 'online';
            final ds = newData['delivery_status'] as String? ?? '';
            final hasActive = _myPickupOrders.isNotEmpty || _myDeliveryOrders.isNotEmpty;

            if (isPaid && isOnline &&
                ['pending', 'waiting_for_rider'].contains(ds) &&
                !hasActive) {
              final code = newData['order_code'] as String? ?? 'New order';
              await NotificationService.showNewOrderAlert(
                title: 'New Pickup Order Available!',
                body: '$code – ₦1,200 pickup fee. Be first to accept!',
              );
              if (mounted) setState(() {});
            }
            if (mounted) _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (payload) async {
            final newData = payload.newRecord;
            final oldData = payload.oldRecord;
            final ds = newData['delivery_status'] as String? ?? '';
            final oldDs = oldData['delivery_status'] as String? ?? '';

            // New delivery job became available
            if (ds == 'ready_for_delivery' &&
                oldDs != 'ready_for_delivery' &&
                newData['rider_id'] == null &&
                newData['delivery_address'] != null &&
                _myDeliveryOrders.isEmpty) {
              final code = newData['order_code'] as String? ?? 'New delivery';
              await NotificationService.showNewOrderAlert(
                title: 'New Delivery Job Available!',
                body: '$code is ready for delivery. Set your price and accept!',
                id: 201,
              );
            }
            if (mounted) _loadData();
          },
        )
        .subscribe();
  }

  Future<void> _acceptPickup(String orderId) async {
    if (_riderProfile == null) return;
    try {
      await SupabaseService.acceptPickup(orderId, _riderProfile!['id']);
      _snack('Pickup accepted! ₦${_kPickupFee.toStringAsFixed(0)} earned', isSuccess: true);
      _loadData();
    } catch (e) {
      _snack('Failed to accept. It may have been taken.');
    }
  }

  Future<void> _acceptDeliveryJob(Map<String, dynamic> order) async {
    if (_riderProfile == null) return;
    double? price;
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Set Your Delivery Price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order: ${order['order_code']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              Text('Deliver to: ${order['delivery_address'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Delivery fee (₦)',
                  hintText: 'e.g. 1500',
                  prefixText: '₦ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                price = double.tryParse(ctrl.text);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _kCyan, foregroundColor: Colors.white),
              child: const Text('Accept Job'),
            ),
          ],
        );
      },
    );
    if (price == null || price! <= 0) return;
    try {
      await SupabaseService.acceptDeliveryJob(order['id'], _riderProfile!['id'], price!);
      _snack('Delivery job accepted! Your fee: ₦${price!.toStringAsFixed(0)}', isSuccess: true);
      _loadData();
    } catch (e) {
      _snack('Failed to accept delivery job.');
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    setState(() => _updatingStatus = true);
    try {
      await SupabaseService.updateDeliveryStatus(orderId, newStatus);
      _snack('Status updated!', isSuccess: true);
      await _loadData();
    } catch (e) {
      _snack('Failed to update status.');
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    await context.read<UserProvider>().clearUser();
    if (mounted) Navigator.pushReplacementNamed(context, '/rider/login');
  }

  void _snack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? Colors.green[700] : Colors.red[700],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_kPrimary))),
      );
    }

    // Pending approval
    final isApproved = _riderProfile?['is_approved'] as bool? ?? false;
    if (_riderProfile != null && !isApproved) {
      return _buildPendingApproval(user);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader(user),
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: _kPrimary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _kPrimary,
              indicatorWeight: 2,
              tabs: const [
                Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Orders'),
                Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Earnings'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersTab(),
                _buildEarningsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(UserProvider user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/icon.png', width: 40, height: 40, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rider Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A1A2E))),
                    Text(user.name ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  final riderId = _riderProfile?['id'] as String?;
                  if (riderId != null) showRiderNotificationsSheet(context, riderId);
                },
                icon: const Icon(Icons.notifications_outlined, size: 22, color: _kPrimary),
                tooltip: 'Notifications',
              ),
              IconButton(
                onPressed: _signOut,
                icon: Icon(Icons.logout, size: 22, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApproval(UserProvider user) {
    final rejection = _riderProfile?['rejection_reason'] as String?;
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(user),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.schedule, size: 40, color: Colors.orange),
                    ),
                    const SizedBox(height: 20),
                    const Text('Pending Approval', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Your rider account is under review. An admin will approve your account shortly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (rejection != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Text('Rejection Reason: $rejection', style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(user.name ?? '', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(user.phone ?? '', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () { setState(() => _loading = true); _loadData(); },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Status'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kPrimary),
                        foregroundColor: _kPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    final hasActivePickup = _myPickupOrders.isNotEmpty;
    final hasActiveDelivery = _myDeliveryOrders.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _kPrimary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // My Active Pickup Orders
          if (hasActivePickup) ...[
            _sectionHeader('My Active Orders (${_myPickupOrders.length})', Icons.local_shipping_outlined, _kPrimary),
            const SizedBox(height: 8),
            ..._myPickupOrders.map((o) => _buildActivePickupCard(o)),
            const SizedBox(height: 16),
          ],

          // Available Pickup Orders
          _sectionHeader(
            'Available Pickup Orders (${hasActivePickup ? 0 : _availablePickups.length})',
            Icons.schedule,
            _kCyan,
          ),
          const SizedBox(height: 8),
          if (hasActivePickup)
            _buildBusyCard('Complete Your Current Job First', 'You have an active job in progress. Complete it to see new available orders.', Icons.local_shipping)
          else if (_availablePickups.isEmpty)
            _buildEmptyCard('No Pickup Orders Available', 'New orders will appear here when customers place them.', Icons.inventory_2_outlined)
          else
            ..._availablePickups.map((o) => _buildAvailablePickupCard(o)),

          const SizedBox(height: 16),

          // My Active Delivery Jobs
          if (hasActiveDelivery) ...[
            _sectionHeader('My Delivery Jobs (${_myDeliveryOrders.length})', Icons.local_shipping, Colors.cyan[700]!),
            const SizedBox(height: 8),
            ..._myDeliveryOrders.map((o) => _buildActiveDeliveryCard(o)),
            const SizedBox(height: 16),
          ],

          // Available Delivery Jobs
          _sectionHeader(
            'Delivery Jobs (${hasActiveDelivery ? 0 : _availableDeliveries.length})',
            Icons.home_outlined,
            Colors.cyan[700]!,
          ),
          const SizedBox(height: 8),
          if (hasActiveDelivery)
            _buildBusyCard('Complete Current Delivery First', 'Finish your active delivery to see new jobs.', Icons.local_shipping)
          else if (_availableDeliveries.isEmpty)
            _buildEmptyCard('No Delivery Jobs', 'Jobs will appear when orders are ready for delivery.', Icons.home_outlined)
          else
            ..._availableDeliveries.map((o) => _buildAvailableDeliveryCard(o)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
      ],
    );
  }

  Widget _buildBusyCard(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.orange),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAvailablePickupCard(Map<String, dynamic> order) {
    final code = order['order_code'] as String? ?? '';
    final pickup = order['pickup_address'] as String? ?? '';
    final delivery = order['delivery_address'] as String?;
    final customer = order['customer_code'] as String? ?? '';
    final items = order['order_items'] as List<dynamic>? ?? [];
    final totalQty = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
    final createdAt = order['created_at'] as String? ?? '';
    String dateStr = '';
    try { dateStr = _fmtDateTime(createdAt); } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Pickup Fee: ₦${_kPickupFee.toStringAsFixed(0)}', style: const TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 10),
                _addressRow(Icons.location_on, Colors.red, 'Pickup Location', pickup),
                if (delivery != null) ...[
                  const SizedBox(height: 6),
                  _addressRow(Icons.location_on, _kGreen, 'Delivery Location', delivery),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(customer, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(width: 12),
                    Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text('$totalQty items', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _updatingStatus ? null : () => _acceptPickup(order['id']),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text('Accept Pickup (₦${_kPickupFee.toStringAsFixed(0)})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDeliveryCard(Map<String, dynamic> order) {
    final code = order['order_code'] as String? ?? '';
    final delivery = order['delivery_address'] as String? ?? '';
    final items = order['order_items'] as List<dynamic>? ?? [];
    final totalQty = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyan.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Ready', style: TextStyle(color: _kCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _addressRow(Icons.location_on, _kGreen, 'Deliver To', delivery),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('$totalQty items', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updatingStatus ? null : () => _acceptDeliveryJob(order),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Set Price & Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePickupCard(Map<String, dynamic> order) {
    final code = order['order_code'] as String? ?? '';
    final ds = order['delivery_status'] as String? ?? '';
    final pickup = order['pickup_address'] as String? ?? '';

    Map<String, dynamic>? nextAction;
    switch (ds) {
      case 'rider_accepted':
        nextAction = {'label': "I'm at pickup location", 'status': 'rider_at_location', 'icon': Icons.navigation};
        break;
      case 'rider_at_location':
        nextAction = {'label': 'Order Picked Up', 'status': 'picked_up', 'icon': Icons.inventory_2_outlined};
        break;
      case 'picked_up':
        nextAction = {'label': 'Order Delivered to Store', 'status': 'delivered_processing', 'icon': Icons.check_circle_outline};
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                _statusBadge(ds),
              ],
            ),
            const SizedBox(height: 10),
            _addressRow(Icons.location_on, Colors.red, 'Pickup', pickup),
            if (nextAction != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _updatingStatus ? null : () => _updateStatus(order['id'], nextAction!['status'] as String),
                  icon: Icon(nextAction['icon'] as IconData, size: 18),
                  label: Text(nextAction['label'] as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryCard(Map<String, dynamic> order) {
    final code = order['order_code'] as String? ?? '';
    final ds = order['delivery_status'] as String? ?? '';
    final delivery = order['delivery_address'] as String? ?? '';
    final fee = (order['delivery_fee'] as num?)?.toDouble() ?? 0.0;

    Map<String, dynamic>? nextAction;
    if (ds == 'delivery_accepted') {
      nextAction = {'label': 'Out for Delivery', 'status': 'out_for_delivery', 'icon': Icons.local_shipping_outlined};
    } else if (ds == 'out_for_delivery') {
      nextAction = {
        'label': 'Delivered (Collect ₦${fee.toStringAsFixed(0)})',
        'status': 'completed',
        'icon': Icons.check_circle_outline,
      };
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCyan.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCyan.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                _statusBadge(ds),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Your fee: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('₦${fee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: _kCyan, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            _addressRow(Icons.location_on, _kGreen, 'Deliver To', delivery),
            if (nextAction != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _updatingStatus ? null : () => _updateStatus(order['id'], nextAction!['status'] as String),
                  icon: Icon(nextAction['icon'] as IconData, size: 18),
                  label: Text(nextAction['label'] as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kCyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsTab() {
    final total = _completedOrders.length * _kPickupFee;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final weekOrders = _completedOrders.where((o) {
      try {
        final dt = DateTime.parse(o['delivered_at'] as String? ?? o['created_at'] as String? ?? '');
        return dt.isAfter(weekStart.subtract(const Duration(days: 1)));
      } catch (_) { return false; }
    }).length;

    final monthOrders = _completedOrders.where((o) {
      try {
        final dt = DateTime.parse(o['delivered_at'] as String? ?? o['created_at'] as String? ?? '');
        return dt.isAfter(monthStart.subtract(const Duration(days: 1)));
      } catch (_) { return false; }
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            children: [
              _statCard('Total Deliveries', '${_completedOrders.length}', Icons.delivery_dining, _kPrimary),
              _statCard('Total Earnings', '₦${total.toStringAsFixed(0)}', Icons.account_balance_wallet, _kGreen),
              _statCard('This Week', '₦${(weekOrders * _kPickupFee).toStringAsFixed(0)}', Icons.calendar_today, _kCyan),
              _statCard('This Month', '₦${(monthOrders * _kPickupFee).toStringAsFixed(0)}', Icons.calendar_month, Colors.orange),
            ],
          ),
          const SizedBox(height: 16),
          // Pending payout card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPrimary.withValues(alpha: 0.08), _kPrimary.withValues(alpha: 0.02)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pending_actions, color: _kPrimary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Pending Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E))),
                  ],
                ),
                const SizedBox(height: 8),
                Text('₦${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _kPrimary)),
                const SizedBox(height: 4),
                Text('Based on ${_completedOrders.length} completed pickup(s)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Recent Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_completedOrders.isEmpty)
            _buildEmptyCard('No completed jobs yet', 'Your completed pickups and deliveries will appear here.', Icons.history)
          else
            ..._completedOrders.take(10).map((o) => _buildCompletedRow(o)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildCompletedRow(Map<String, dynamic> o) {
    final code = o['order_code'] as String? ?? '';
    final at = o['delivered_at'] as String? ?? o['created_at'] as String? ?? '';
    String dateStr = '';
    try { dateStr = _fmtDate(at); } catch (_) {}
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.check_circle_outline, size: 18, color: _kGreen),
            const SizedBox(width: 8),
            Text(code, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₦${_kPickupFee.toStringAsFixed(0)}', style: const TextStyle(color: _kGreen, fontWeight: FontWeight.bold)),
              Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addressRow(IconData icon, Color color, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(address, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String ds) {
    Color color;
    String label;
    switch (ds) {
      case 'rider_accepted': color = Colors.blue[600]!; label = 'Accepted'; break;
      case 'rider_at_location': color = Colors.purple[600]!; label = 'At Location'; break;
      case 'picked_up': color = Colors.orange[700]!; label = 'Picked Up'; break;
      case 'delivered_processing': color = _kGreen; label = 'Delivered'; break;
      case 'delivery_accepted': color = Colors.blue[600]!; label = 'Delivery Accepted'; break;
      case 'out_for_delivery': color = Colors.orange[700]!; label = 'Out for Delivery'; break;
      case 'completed': color = _kGreen; label = 'Completed'; break;
      default: color = Colors.grey; label = ds;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _fmtDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m $ampm';
    } catch (_) { return iso; }
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return iso; }
  }
}
