import 'package:flutter/material.dart';

class OrderItem {
  final String category;
  final String serviceType;
  int quantity;
  final double pricePerItem;

  OrderItem({
    required this.category,
    required this.serviceType,
    required this.quantity,
    required this.pricePerItem,
  });

  double get subtotal => quantity * pricePerItem;

  Map<String, dynamic> toMap() => {
        'category': category,
        'service_type': serviceType,
        'quantity': quantity,
        'price_per_item': pricePerItem,
        'subtotal': subtotal,
      };
}

class OrderProvider extends ChangeNotifier {
  final List<OrderItem> _items = [];
  bool _isExpress = false;
  String _pickupAddress = '';
  String _deliveryAddress = '';

  List<OrderItem> get items => List.unmodifiable(_items);
  bool get isExpress => _isExpress;
  String get pickupAddress => _pickupAddress;
  String get deliveryAddress => _deliveryAddress;

  int get totalItems => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => _items.fold(0.0, (sum, i) => sum + i.subtotal);

  double get expressCharge => _isExpress ? subtotal * 0.5 : 0.0;

  double get deliveryCharge => 1500.0; // flat ₦1,500

  double get total => subtotal + expressCharge + deliveryCharge;

  void addItem(OrderItem item) {
    final idx = _items.indexWhere(
      (i) => i.category == item.category && i.serviceType == item.serviceType,
    );
    if (idx >= 0) {
      _items[idx].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void incrementItem(String category, String serviceType) {
    final idx = _items.indexWhere(
      (i) => i.category == category && i.serviceType == serviceType,
    );
    if (idx >= 0) {
      _items[idx].quantity++;
      notifyListeners();
    }
  }

  void decrementItem(String category, String serviceType) {
    final idx = _items.indexWhere(
      (i) => i.category == category && i.serviceType == serviceType,
    );
    if (idx >= 0) {
      if (_items[idx].quantity <= 1) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity--;
      }
      notifyListeners();
    }
  }

  void removeItem(String category, String serviceType) {
    _items.removeWhere(
      (i) => i.category == category && i.serviceType == serviceType,
    );
    notifyListeners();
  }

  void setExpress(bool value) {
    _isExpress = value;
    notifyListeners();
  }

  void setPickupAddress(String v) {
    _pickupAddress = v;
    notifyListeners();
  }

  void setDeliveryAddress(String v) {
    _deliveryAddress = v;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _isExpress = false;
    _pickupAddress = '';
    _deliveryAddress = '';
    notifyListeners();
  }

  int getItemQuantity(String category, String serviceType) {
    final idx = _items.indexWhere(
      (i) => i.category == category && i.serviceType == serviceType,
    );
    return idx >= 0 ? _items[idx].quantity : 0;
  }
}
