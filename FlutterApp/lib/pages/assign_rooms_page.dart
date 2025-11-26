import 'package:flutter/material.dart';
import '../models/rooms.dart';
import 'go_to_room_page.dart';

class AssignRoomsPage extends StatefulWidget {
  final List<String> selectedBeacons;
  const AssignRoomsPage({super.key, required this.selectedBeacons});

  @override
  State<AssignRoomsPage> createState() => _AssignRoomsPageState();
}

class _AssignRoomsPageState extends State<AssignRoomsPage> {
  final Map<String, String> _assignments = {};
  final Map<String, bool> _expanded = {};

  @override
  void initState() {
    super.initState();
    for (final b in widget.selectedBeacons) {
      _expanded[b] = false;
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
          } // End if
          final beacon = widget.selectedBeacons[index - 1];
          final assigned = _assignments[beacon];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              key: ValueKey(
                '$beacon-${(_expanded[beacon] ?? false) ? 'open' : 'closed'}',
              ),
              initiallyExpanded: _expanded[beacon] ?? false,
              onExpansionChanged: (isOpen) {
                setState(() {
                  // Allow only one tile open at a time
                  for (final b in widget.selectedBeacons) {
                    _expanded[b] = false;
                  }
                  _expanded[beacon] = isOpen;
                });
              },
              title: Text(beacon + (assigned != null ? ' • $assigned' : '')),
              subtitle: assigned == null
                  ? const Text('Tap to select a room')
                  : const Text('Assigned'),
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
                            groupValue: _assignments[beacon],
                            onChanged: (value) {
                              setState(() {
                                if (value != null) {
                                  _assignments[beacon] = value;
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
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GoToRoomPage(assignments: Map.of(_assignments)),
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
