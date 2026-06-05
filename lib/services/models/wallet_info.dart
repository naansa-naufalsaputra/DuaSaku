/// A lightweight DTO representing wallet information for service layer use.
///
/// Used to pass wallet context to parsing services without coupling
/// to the full WalletModel from the data layer.
class WalletInfo {
  final String id;
  final String name;
  final String type;

  const WalletInfo({required this.id, required this.name, required this.type});
}
