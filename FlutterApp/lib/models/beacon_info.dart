/// Represents a Bluetooth beacon with its MAC address and optional display name.
class BeaconInfo {
  final String address; // MAC address (e.g., "AA:BB:CC:DD:EE:FF")
  final String name;    // Display name (may be empty)

  const BeaconInfo({required this.address, this.name = ''});

  String get displayName => name.isNotEmpty ? name : address;

  @override
  String toString() => name.isNotEmpty ? '$name ($address)' : address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeaconInfo &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;
}

/// Assignment of a beacon to a room for calibration.
class BeaconRoomAssignment {
  final BeaconInfo beacon;
  final String room;

  const BeaconRoomAssignment({required this.beacon, required this.room});
}

