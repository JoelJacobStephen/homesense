import 'package:flutter/material.dart';
import '../models/beacon_info.dart';
import '../models/rooms.dart';
import 'go_to_room_page.dart';

class AssignRoomsPage extends StatefulWidget {
  final List<BeaconInfo> selectedBeacons;
  const AssignRoomsPage({super.key, required this.selectedBeacons});

  @override
  State<AssignRoomsPage> createState() => _AssignRoomsPageState();
}

class _AssignRoomsPageState extends State<AssignRoomsPage> {
  final Map<String, String> _assignments = {};

  bool get _allAssigned =>
      _assignments.length == widget.selectedBeacons.length;

  int get _assignedCount => _assignments.length;

  // Room icons mapping
  IconData _getRoomIcon(String room) {
    switch (room.toLowerCase()) {
      case 'bedroom':
      case 'bedroom 2':
      case 'guest room':
        return Icons.bed_rounded;
      case 'bathroom':
        return Icons.bathtub_rounded;
      case 'kitchen':
        return Icons.kitchen_rounded;
      case 'dining room':
        return Icons.dining_rounded;
      case 'living room':
        return Icons.weekend_rounded;
      case 'home theatre':
        return Icons.tv_rounded;
      case 'game room':
        return Icons.sports_esports_rounded;
      case 'fireplace':
        return Icons.fireplace_rounded;
      default:
        return Icons.room_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and step indicator row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF4A5568),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Step 2 of 3',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Assign rooms',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A202C),
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose which room each beacon is located in. This helps us track your location accurately.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    '$_assignedCount of ${widget.selectedBeacons.length} assigned',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.selectedBeacons.isEmpty
                            ? 0
                            : _assignedCount / widget.selectedBeacons.length,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF38B2AC),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Beacon list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: widget.selectedBeacons.length,
                itemBuilder: (context, index) {
                  final beacon = widget.selectedBeacons[index];
                  final assigned = _assignments[beacon.address];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: assigned != null
                          ? const Color(0xFFF0FFF4)
                          : const Color(0xFFF7FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: assigned != null
                            ? const Color(0xFF38B2AC).withOpacity(0.3)
                            : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showRoomPicker(beacon),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Beacon icon
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: assigned != null
                                      ? const Color(0xFF38B2AC).withOpacity(0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.bluetooth_rounded,
                                  color: assigned != null
                                      ? const Color(0xFF38B2AC)
                                      : Colors.grey[400],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Beacon info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      beacon.displayName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      assigned ?? 'Tap to assign room',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: assigned != null
                                            ? const Color(0xFF38B2AC)
                                            : Colors.grey[500],
                                        fontWeight: assigned != null
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status icon
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: assigned != null
                                      ? const Color(0xFF38B2AC)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  assigned != null
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_ios_rounded,
                                  color: assigned != null
                                      ? Colors.white
                                      : Colors.grey[400],
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom action
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[100]!,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _allAssigned
                      ? () {
                          final assignments = widget.selectedBeacons
                              .map((b) => BeaconRoomAssignment(
                                    beacon: b,
                                    room: _assignments[b.address]!,
                                  ))
                              .toList();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  GoToRoomPage(assignments: assignments),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoomPicker(BeaconInfo beacon) async {
    final selectedRoom = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Room',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A202C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'for ${beacon.displayName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Room grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
                itemCount: Rooms.all.length,
                itemBuilder: (_, i) {
                  final room = Rooms.all[i];
                  final isSelected = _assignments[beacon.address] == room;
                  final isUsed = _assignments.values.contains(room) &&
                      _assignments[beacon.address] != room;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isUsed
                          ? null
                          : () => Navigator.of(ctx).pop(room),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF38B2AC).withOpacity(0.1)
                              : isUsed
                                  ? Colors.grey[100]
                                  : const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF38B2AC)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getRoomIcon(room),
                              size: 28,
                              color: isSelected
                                  ? const Color(0xFF38B2AC)
                                  : isUsed
                                      ? Colors.grey[400]
                                      : const Color(0xFF4A5568),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              room,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF38B2AC)
                                    : isUsed
                                        ? Colors.grey[400]
                                        : const Color(0xFF4A5568),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (isUsed)
                              Text(
                                'In use',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedRoom != null) {
      setState(() {
        _assignments[beacon.address] = selectedRoom;
      });
    }
  }
}
