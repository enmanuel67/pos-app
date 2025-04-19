class Client {
  final int? id;
  final String name;
  final String lastName;
  final String phone; // Este es el ID del cliente
  final String address;
  final String email;
  final bool hasCredit;
  final double creditLimit;

  Client({
    this.id,
    required this.name,
    required this.lastName,
    required this.phone,
    required this.address,
    required this.email,
    required this.hasCredit,
    required this.creditLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lastName': lastName,
      'phone': phone,
      'address': address,
      'email': email,
      'hasCredit': hasCredit ? 1 : 0,
      'creditLimit': creditLimit,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      lastName: map['lastName'],
      phone: map['phone'],
      address: map['address'],
      email: map['email'],
      hasCredit: map['hasCredit'] == 1,
      creditLimit: map['creditLimit']?.toDouble() ?? 0.0,
    );
  }
}
