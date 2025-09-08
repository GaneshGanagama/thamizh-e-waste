import 'package:flutter/material.dart';

class TrackStatusScreen extends StatelessWidget {
  const TrackStatusScreen({super.key}); // ✅ Added const constructor

  final List<Map<String, dynamic>> dummyRequests = const [
    {
      'wasteType': 'Mobile Phone',
      'address': '123, Anna Nagar, Chennai',
      'status': 'Pending',
      'date': '2025-07-01',
    },
    {
      'wasteType': 'TV',
      'address': '7/22, KK Nagar, Madurai',
      'status': 'Scheduled',
      'date': '2025-07-02',
    },
    {
      'wasteType': 'Laptop',
      'address': '22, Gandhi Road, Coimbatore',
      'status': 'Completed',
      'date': '2025-06-29',
    },
  ];

  Color getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Scheduled':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Track My Pickups"),
        backgroundColor: Colors.green[700],
      ),
      body: dummyRequests.isEmpty
          ? const Center(
              child: Text(
                "No pickup requests found.",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dummyRequests.length,
              itemBuilder: (context, index) {
                final request = dummyRequests[index];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ListTile(
                      leading: Icon(
                        Icons.recycling,
                        size: 32,
                        color: getStatusColor(request['status']),
                      ),
                      title: Text(
                        request['wasteType'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request['address']),
                          const SizedBox(height: 4),
                          Text("Date: ${request['date']}"),
                        ],
                      ),
                      trailing: Text(
                        request['status'],
                        style: TextStyle(
                          color: getStatusColor(request['status']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
