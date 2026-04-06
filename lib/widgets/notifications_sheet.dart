import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

const _kPrimary = Color(0xFF9333EA);

/// Shows a bottom sheet of recent order notifications for a customer.
Future<void> showCustomerNotificationsSheet(
    BuildContext context, String userId) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomerNotificationsSheet(userId: userId),
  );
}

/// Shows a bottom sheet of recent/available order alerts for a rider.
Future<void> showRiderNotificationsSheet(
    BuildContext context, String riderId) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RiderNotificationsSheet(riderId: riderId),
  );
}

// ─── Customer sheet ──────────────────────────────────────────────────────────

class _CustomerNotificationsSheet extends StatefulWidget {
  final String userId;
  const _CustomerNotificationsSheet({required this.userId});
  @override
  State<_CustomerNotificationsSheet> createState() =>
      _CustomerNotificationsSheetState();
}

class _CustomerNotificationsSheetState
    extends State<_CustomerNotificationsSheet> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await SupabaseService.getCustomerOrders(widget.userId);
    if (mounted) setState(() { _orders = orders.take(10).toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Notifications',
      child: _loading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: _kPrimary)))
          : _orders.isEmpty
              ? _empty('No order updates yet')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (_, i) => _CustomerOrderTile(_orders[i]),
                ),
    );
  }
}

class _CustomerOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  const _CustomerOrderTile(this.order);

  @override
  Widget build(BuildContext context) {
    final ds = order['delivery_status'] as String? ?? 'pending';
    final code = order['order_code'] as String? ?? '';
    final info = _dsInfo(ds);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: info.color.withValues(alpha: 0.12),
        child: Icon(info.icon, size: 18, color: info.color),
      ),
      title: Text(code,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(info.label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Text(_statusBadge(order['payment_status'] as String? ?? ''),
          style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500)),
    );
  }

  String _statusBadge(String s) => switch (s) {
        'paid' => 'PAID',
        'pending' => 'UNPAID',
        _ => s.toUpperCase(),
      };

  _DsInfo _dsInfo(String ds) => switch (ds) {
        'rider_accepted' =>
          _DsInfo(Icons.directions_bike, Colors.blue, 'Rider on the way'),
        'rider_at_location' =>
          _DsInfo(Icons.location_on, Colors.indigo, 'Rider arrived'),
        'picked_up' =>
          _DsInfo(Icons.inventory_2_outlined, Colors.purple, 'Laundry picked up'),
        'delivered_processing' =>
          _DsInfo(Icons.local_laundry_service, _kPrimary, 'Being cleaned'),
        'ready_for_delivery' =>
          _DsInfo(Icons.check_circle_outline, Colors.teal, 'Ready for delivery'),
        'delivery_accepted' =>
          _DsInfo(Icons.local_shipping_outlined, Colors.cyan[700]!, 'Delivery rider assigned'),
        'out_for_delivery' =>
          _DsInfo(Icons.local_shipping, Colors.orange, 'Out for delivery'),
        'completed' =>
          _DsInfo(Icons.check_circle, Colors.green, 'Delivered'),
        _ => _DsInfo(Icons.receipt_long_outlined, Colors.grey, 'Order placed'),
      };
}

class _DsInfo {
  final IconData icon;
  final Color color;
  final String label;
  const _DsInfo(this.icon, this.color, this.label);
}

// ─── Rider sheet ─────────────────────────────────────────────────────────────

class _RiderNotificationsSheet extends StatefulWidget {
  final String riderId;
  const _RiderNotificationsSheet({required this.riderId});
  @override
  State<_RiderNotificationsSheet> createState() =>
      _RiderNotificationsSheetState();
}

class _RiderNotificationsSheetState extends State<_RiderNotificationsSheet> {
  List<Map<String, dynamic>> _available = [];
  List<Map<String, dynamic>> _myActive = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.getAvailablePickupOrders(),
      SupabaseService.getRiderPickupOrders(widget.riderId),
    ]);
    if (mounted) {
      setState(() {
        _available = results[0];
        _myActive = results[1];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: 'Order Alerts',
      child: _loading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: _kPrimary)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_myActive.isNotEmpty) ...[
                  _sectionLabel('Active Jobs'),
                  ..._myActive.map((o) => _RiderOrderTile(o,
                      color: Colors.green, label: 'In Progress')),
                  const SizedBox(height: 8),
                ],
                if (_available.isNotEmpty) ...[
                  _sectionLabel('Available Pickups'),
                  ..._available.map((o) => _RiderOrderTile(o,
                      color: Colors.orange, label: '₦1,200 fee')),
                ] else if (_myActive.isEmpty)
                  _empty('No new orders right now'),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.5)),
      );
}

class _RiderOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final Color color;
  final String label;
  const _RiderOrderTile(this.order, {required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final code = order['order_code'] as String? ?? '';
    final pickup = order['pickup_address'] as String? ?? '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(Icons.local_shipping_outlined, size: 18, color: color),
      ),
      title: Text(code,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(pickup,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── Shared shell ─────────────────────────────────────────────────────────────

Widget _empty(String msg) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.notifications_none, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(msg,
                style:
                    TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );

class _SheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      size: 20, color: _kPrimary),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
