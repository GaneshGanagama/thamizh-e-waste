import 'package:flutter/material.dart';

class AdminManageRequestsScreen extends StatefulWidget {
  const AdminManageRequestsScreen({super.key});

  @override
  _AdminManageRequestsScreenState createState() =>
      _AdminManageRequestsScreenState();
}

class _AdminManageRequestsScreenState extends State<AdminManageRequestsScreen> {
  List<Map<String, dynamic>> pickupRequests = [
    {
      'id': '1',
      'wasteType': 'Battery',
      'user': 'Arun',
      'address': 'Plot 5, Velachery, Chennai',
      'status': 'Pending',
    },
    {
      'id': '2',
      'wasteType': 'Printer',
      'user': 'Meena',
      'address': '13, Race Course, Coimbatore',
      'status': 'Scheduled',
    },
    {
      'id': '3',
      'wasteType': 'Mobile',
      'user': 'Karthik',
      'address': '1/2, Madurai Main St.',
      'status': 'Completed',
    },
  ];

  List<String> statusOptions = ['Pending', 'Scheduled', 'Completed'];

  void updateStatus(int index, String newStatus) {
    setState(() {
      pickupRequests[index]['status'] = newStatus;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated to $newStatus')),
    );

    // TODO: Save to Firestore here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Pickup Requests")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pickupRequests.length,
        itemBuilder: (context, index) {
          final request = pickupRequests[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.recycling, color: Colors.green),
              title: Text('${request['wasteType']} - ${request['user']}'),
              subtitle: Text(request['address']),
              trailing: DropdownButton<String>(
                value: request['status'],
                underline: SizedBox(),
                items: statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    updateStatus(index, value);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
