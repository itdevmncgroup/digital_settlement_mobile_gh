/// Payment method master-data option - id+code+name. `code` drives the
/// conditional credit-card/e-wallet-note UI, `name` is the display label.
class PaymentMethodOption {
  final String id;
  final String code;
  final String name;

  PaymentMethodOption({required this.id, required this.code, required this.name});

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) => PaymentMethodOption(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String? ?? '',
      );
}
