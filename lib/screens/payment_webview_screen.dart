import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _kPrimary = Color(0xFF9333EA);

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String redirectUrl; // detect this URL to know payment finished

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.redirectUrl,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          // Flutterwave redirects here after payment (success or failure)
          if (request.url.startsWith(widget.redirectUrl)) {
            final uri = Uri.tryParse(request.url);
            final status = uri?.queryParameters['status'] ?? '';
            Navigator.pop(context, status == 'successful' || status == 'completed');
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Secure Payment',
          style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kPrimary),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _loading
              ? const LinearProgressIndicator(
                  color: _kPrimary,
                  backgroundColor: Color(0xFFF3E8FF),
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
