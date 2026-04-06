import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/notifications_sheet.dart';

const kBtnGradient = [Color(0xFF0891B2), Color(0xFF16A34A)];
const kPrimary = Color(0xFF9333EA);

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  List<Map<String, dynamic>> _priceItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPriceItems();
  }

  Future<void> _loadPriceItems() async {
    try {
      final items = await SupabaseService.getPriceItems();
      setState(() { _priceItems = items; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // Group by category
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in _priceItems) {
      map.putIfAbsent(item['category'] as String, () => []).add(item);
    }
    return map;
  }

  List<String> get _categories => _grouped.keys.toList();

  void _openCategoryDialog(String category) {
    final items = _grouped[category] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ServicePickerSheet(category: category, items: items),
    );
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    await context.read<UserProvider>().clearUser();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final order = context.watch<OrderProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5FF),
      body: Column(
        children: [
          _buildHeader(user, order),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(kPrimary)))
                : _buildBody(order),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(UserProvider user, OrderProvider order) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
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
                    const Text('Place Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    Text('Welcome, ${user.name?.split(' ').first ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/track'),
                icon: const Icon(Icons.list_alt, size: 14),
                label: const Text('My Orders', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: const BorderSide(color: kPrimary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  final userId = context.read<UserProvider>().userId;
                  if (userId != null) showCustomerNotificationsSheet(context, userId);
                },
                icon: const Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF9333EA)),
                tooltip: 'Notifications',
              ),
              IconButton(onPressed: _logout, icon: const Icon(Icons.logout, size: 20, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(OrderProvider order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Items Card
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.shopping_cart_outlined, size: 18, color: kPrimary),
                const SizedBox(width: 8),
                const Text('Order Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 2),
              Text('Tap a category to add items', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 16),
              // Category grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.6,
                children: _categories.map((cat) => _CategoryBadge(
                  category: cat,
                  onTap: () => _openCategoryDialog(cat),
                )).toList(),
              ),
              // Added items
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Text('Added Items (${order.items.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                const SizedBox(height: 8),
                ...order.items.map((item) => _AddedItemRow(item: item, onRemove: () => order.removeItem(item.category, item.serviceType))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Pickup Address
        _PickupCard(order: order),
        const SizedBox(height: 12),
        // Express
        _ExpressCard(order: order),
        const SizedBox(height: 12),
        // Order Summary
        if (order.items.isNotEmpty) _SummaryCard(order: order),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: 0,
          onTap: (i) {
            if (i == 1) Navigator.pushNamed(context, '/track');
            if (i == 2) Navigator.pushNamed(context, '/profile');
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: kPrimary,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: 'Order'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: 'My Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─── Category icon helper ─────────────────────────────────────────────────────

String categoryEmoji(String category) {
  final c = category.toLowerCase().trim();
  if (c.contains('trouser') || c.contains('pant')) return '👖';
  if (c.contains('shirt') || c.contains('top') || c.contains('blouse')) return '👕';
  if (c.contains('dress')) return '👗';
  if (c.contains('suit') || c.contains('blazer') || c.contains('jacket')) return '🧥';
  if (c.contains('skirt')) return '🩱';
  if (c.contains('underwear') || c.contains('boxer') || c.contains('brief')) return '🩲';
  if (c.contains('sock')) return '🧦';
  if (c.contains('bed') || c.contains('sheet') || c.contains('duvet') || c.contains('pillow')) return '🛏️';
  if (c.contains('towel')) return '🏖️';
  if (c.contains('cap') || c.contains('hat')) return '🧢';
  if (c.contains('sweater') || c.contains('hoodie') || c.contains('pullover')) return '🧶';
  if (c.contains('tie') || c.contains('scarf')) return '🧣';
  if (c.contains('shoe') || c.contains('boot')) return '👟';
  if (c.contains('bag') || c.contains('purse')) return '👜';
  if (c.contains('curtain') || c.contains('rug') || c.contains('carpet')) return '🪟';
  if (c.contains('coat')) return '🧥';
  if (c.contains('jumpsuit') || c.contains('overall')) return '🥻';
  if (c.contains('short')) return '🩳';
  return '👔';
}

// ─── Category badge ───────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String category;
  final VoidCallback onTap;
  const _CategoryBadge({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E8FF), Color(0xFFEEF2FF)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: Text(categoryEmoji(category), style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.add, size: 13, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─── Added item row ───────────────────────────────────────────────────────────

class _AddedItemRow extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onRemove;
  const _AddedItemRow({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(categoryEmoji(item.category), style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(item.serviceType, style: const TextStyle(fontSize: 11, color: kPrimary)),
            ]),
          ),
          Text('Qty: ${item.quantity}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(width: 8),
          Text('₦${item.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 4),
          GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── Service picker bottom sheet ──────────────────────────────────────────────

class _ServicePickerSheet extends StatefulWidget {
  final String category;
  final List<Map<String, dynamic>> items;
  const _ServicePickerSheet({required this.category, required this.items});
  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  Map<String, int> _quantities = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(categoryEmoji(widget.category), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(widget.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 12),
          ...widget.items.map((item) {
            final service = item['service_type'] as String;
            final price = (item['price_per_item'] as num).toDouble();
            final qty = _quantities[service] ?? 0;
            return ListTile(
              title: Text(service, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('₦${price.toStringAsFixed(0)} / item', style: const TextStyle(color: kPrimary, fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallQtyBtn(icon: Icons.remove, onTap: qty > 0 ? () => setState(() => _quantities[service] = qty - 1) : null),
                  SizedBox(width: 32, child: Center(child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
                  _SmallQtyBtn(icon: Icons.add, onTap: () => setState(() => _quantities[service] = qty + 1)),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                final order = context.read<OrderProvider>();
                _quantities.forEach((service, qty) {
                  if (qty > 0) {
                    final item = widget.items.firstWhere((i) => i['service_type'] == service);
                    order.addItem(OrderItem(
                      category: widget.category,
                      serviceType: service,
                      quantity: qty,
                      pricePerItem: (item['price_per_item'] as num).toDouble(),
                    ));
                  }
                });
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: kBtnGradient), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Add to Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SmallQtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SmallQtyBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: onTap == null ? Colors.grey[300]! : kPrimary),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: onTap == null ? Colors.grey[300] : kPrimary),
    ),
  );
}

// ─── Pickup Card ──────────────────────────────────────────────────────────────

class _PickupCard extends StatefulWidget {
  final OrderProvider order;
  const _PickupCard({required this.order});
  @override
  State<_PickupCard> createState() => _PickupCardState();
}

class _PickupCardState extends State<_PickupCard> {
  final _ctrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.order.pickupAddress;
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.location_on_outlined, size: 18, color: kPrimary),
        const SizedBox(width: 8),
        const Text('Pickup Address', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 2),
      Text("We'll pick up your laundry from this address", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      const SizedBox(height: 12),
      TextField(
        controller: _ctrl,
        maxLines: 2,
        onChanged: widget.order.setPickupAddress,
        decoration: InputDecoration(
          hintText: 'Enter your full pickup address',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          filled: true, fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimary)),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Pickup Fee:', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const Text('₦1,500', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]));
  }
}

// ─── Express Card ─────────────────────────────────────────────────────────────

class _ExpressCard extends StatelessWidget {
  final OrderProvider order;
  const _ExpressCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final readyDate = DateTime.now().add(Duration(days: order.isExpress ? 1 : 4));
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(readyDate);
    return _Card(child: Column(children: [
      Row(children: [
        Icon(Icons.flash_on, size: 18, color: order.isExpress ? const Color(0xFFEC4899) : kPrimary),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Express Service', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('24-hour turnaround (+₦${order.expressCharge.toStringAsFixed(0)})', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ])),
        if (order.isExpress)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(12)),
            child: Text('+₦${order.expressCharge.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFFEC4899), fontWeight: FontWeight.w600)),
          ),
        Switch(
          value: order.isExpress,
          onChanged: order.setExpress,
          activeColor: const Color(0xFFEC4899),
          activeTrackColor: const Color(0xFFFCE7F3),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: order.isExpress
                ? [const Color(0xFFFDF2F8), const Color(0xFFFCE7F3)]
                : [const Color(0xFFF3E8FF), const Color(0xFFEEF2FF)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: order.isExpress ? const Color(0xFFF9A8D4) : kPrimary.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (order.isExpress ? const Color(0xFFEC4899) : kPrimary).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.calendar_today, size: 20, color: order.isExpress ? const Color(0xFFEC4899) : kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Estimated Ready Date', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              if (order.isExpress) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [Icon(Icons.flash_on, size: 10, color: Color(0xFFEC4899)), SizedBox(width: 2), Text('EXPRESS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEC4899)))]),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(dateStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: order.isExpress ? const Color(0xFFEC4899) : kPrimary)),
            const SizedBox(height: 2),
            Text(order.isExpress ? '⚡ Ready in 24 hours' : '📅 Ready in 4 days', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ])),
        ]),
      ),
    ]));
  }
}

// ─── Order Summary Card ───────────────────────────────────────────────────────

class _SummaryCard extends StatefulWidget {
  final OrderProvider order;
  const _SummaryCard({required this.order});
  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _submitting = false;

  Future<void> _placeOrder() async {
    final order = widget.order;
    if (order.items.isEmpty) { _snack('Add at least one item'); return; }
    if (order.pickupAddress.isEmpty) { _snack('Enter a pickup address'); return; }
    setState(() => _submitting = true);
    try {
      final user = context.read<UserProvider>();
      final orderCode = SupabaseService.generateOrderCode();
      final readyDate = DateTime.now().add(Duration(days: order.isExpress ? 1 : 4));
      final profile = await SupabaseService.getCustomerProfile(user.userId!);
      final createdOrder = await SupabaseService.createOrder({
        'customer_id': profile?['id'],
        'customer_code': user.name,
        'order_code': orderCode,
        'order_type': 'online',
        'pickup_address': order.pickupAddress,
        'delivery_address': order.deliveryAddress.isNotEmpty ? order.deliveryAddress : null,
        'subtotal': order.subtotal,
        'express_charge': order.expressCharge,
        'delivery_charge': order.deliveryCharge,
        'total': order.total,
        'ready_date': readyDate.toIso8601String().split('T').first,
        'status': 'pending',
        'payment_status': 'pending',
        'delivery_status': 'pending',
      });
      // Insert order items
      await SupabaseService.createOrderItems(
        createdOrder['id'] as String,
        order.items.map((item) => {
          'order_id': createdOrder['id'],
          'category': item.category,
          'service_type': item.serviceType,
          'quantity': item.quantity,
          'price_per_item': item.pricePerItem,
          'subtotal': item.subtotal,
        }).toList(),
      );
      if (!mounted) return;
      await _launchPayment(orderCode, user, order.total);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _launchPayment(String orderCode, UserProvider user, double amount) async {
    final pubKey = dotenv.env['FLUTTERWAVE_PUBLIC_KEY'] ?? '';
    final ref = 'LH_${DateTime.now().millisecondsSinceEpoch}';
    final url = Uri.parse(
      'https://checkout.flutterwave.com/v3/hosted/pay'
      '?public_key=$pubKey&tx_ref=$ref'
      '&amount=${amount.toStringAsFixed(2)}&currency=NGN'
      '&redirect_url=https://viovlxpsrjpobysmydtq.supabase.co/functions/v1/flutterwave-webhook'
      '&customer[email]=${Uri.encodeComponent(user.email ?? '')}'
      '&customer[name]=${Uri.encodeComponent(user.name ?? '')}'
      '&customizations[title]=LaundryHouse&customizations[description]=Order $orderCode',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        widget.order.clearCart();
        Navigator.pushNamed(context, '/track');
      }
    } else {
      _snack('Could not open payment page');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return _Card(
      borderColor: kPrimary.withValues(alpha: 0.3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Order Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _Row('Subtotal', '₦${order.subtotal.toStringAsFixed(0)}'),
        _Row('Pickup Fee', '₦1,500'),
        if (order.isExpress) _Row('Express Charge', '₦${order.expressCharge.toStringAsFixed(0)}'),
        const Divider(height: 20),
        _Row('Total', '₦${order.total.toStringAsFixed(0)}', bold: true, color: kPrimary),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _submitting ? null : _placeOrder,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: kBtnGradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: const Color(0xFF0891B2).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : Text('Pay ₦${order.total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label; final String value; final bool bold; final Color? color;
  const _Row(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color ?? const Color(0xFF1A1A2E))),
    ]),
  );
}

// ─── Shared card widget ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const _Card({required this.child, this.borderColor});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? Colors.grey.shade200),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}
