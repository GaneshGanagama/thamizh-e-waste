import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Widget buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              SizedBox(height: 5),
              Text(title,
                  style: TextStyle(fontSize: 14, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> getUserName(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists && userDoc['name'] != null) {
        return userDoc['name'];
      } else {
        return 'Unknown';
      }
    } catch (e) {
      return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pickup_requests')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }

                final docs = snapshot.data!.docs;
                final total = docs.length;
                final pending =
                    docs.where((doc) => doc['status'] == 'Pending').length;
                final completed =
                    docs.where((doc) => doc['status'] == 'Completed').length;

                return Row(
                  children: [
                    buildStatCard("Total Requests", "$total", Colors.blue),
                    SizedBox(width: 10),
                    buildStatCard("Pending", "$pending", Colors.orange),
                    SizedBox(width: 10),
                    buildStatCard("Completed", "$completed", Colors.green),
                  ],
                );
              },
            ),
            SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Recent Pickup Requests",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pickup_requests')
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final requests = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final data =
                          requests[index].data() as Map<String, dynamic>;
                      final userId = data['userId'] ?? '';

                      return FutureBuilder<String>(
                        future: getUserName(userId),
                        builder: (context, userSnapshot) {
                          String userName = userSnapshot.data ?? 'Loading...';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading:
                                  Icon(Icons.recycling, color: Colors.green),
                              title: Text(data['wasteType'] ?? 'Unknown'),
                              subtitle: Text(
                                "User: $userName | Date: ${data['date'] ?? 'Unknown'}",
                              ),
                              trailing: Text(
                                data['status'] ?? 'Pending',
                                style: TextStyle(
                                  color: (data['status'] == 'Completed')
                                      ? Colors.green
                                      : (data['status'] == 'Pending')
                                          ? Colors.orange
                                          : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Divider(),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin_manage_requests');
                  },
                  icon: Icon(Icons.assignment),
                  label: Text("Manage Requests"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin_dropoff');
                  },
                  icon: Icon(Icons.location_on),
                  label: Text("Drop-Off Points"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin_info_post');
                  },
                  icon: Icon(Icons.post_add),
                  label: Text("Post Info/News"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
