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
  // Map from beacon MAC address to assigned room name
  final Map<String, String> _assignments = {};
  final Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    for (final b in widget.selectedBeacons) {
      _expanded[b.address] = false;
    }
  }

  bool get _allAssigned => _assignments.length == widget.selectedBeacons.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Rooms')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.selectedBeacons.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Tap a beacon to choose its room',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          final beacon = widget.selectedBeacons[index - 1];
          final assigned = _assignments[beacon.address];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              key: ValueKey(
                '${beacon.address}-${(_expanded[beacon.address] ?? false) ? 'open' : 'closed'}',
              ),
              initiallyExpanded: _expanded[beacon.address] ?? false,
              onExpansionChanged: (isOpen) {
                setState(() {
                  // Allow only one tile open at a time
                  for (final b in widget.selectedBeacons) {
                    _expanded[b.address] = false;
                  }
                  _expanded[beacon.address] = isOpen;
                });
              },
              title: Text('${beacon.displayName}${assigned != null ? ' • $assigned' : ''}'),
              subtitle: Text(assigned == null ? 'Tap to select a room' : 'Assigned'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select the room this beacon is located in',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ...Rooms.all.map((room) => RadioListTile<String>(
                            title: Text(room),
                            value: room,
                            groupValue: _assignments[beacon.address],
                            onChanged: (value) {
                              setState(() {
                                if (value != null) {
                                  _assignments[beacon.address] = value;
                                }
                              });
                            },
                          )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _allAssigned
                ? () {
                    // Build list of BeaconRoomAssignment
                    final assignments = widget.selectedBeacons
                        .map((b) => BeaconRoomAssignment(
                              beacon: b,
                              room: _assignments[b.address]!,
                            ))
                        .toList();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GoToRoomPage(assignments: assignments),
                      ),
                    );
                  }
                : null,
            child: const Text('Next'),
          ),
        ),
      ),
    );
  }
}
