import 'package:flutter/material.dart';

class AdminInfoPostScreen extends StatefulWidget {
  const AdminInfoPostScreen({super.key});

  @override
  _AdminInfoPostScreenState createState() => _AdminInfoPostScreenState();
}

class _AdminInfoPostScreenState extends State<AdminInfoPostScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  List<Map<String, String>> posts = [
    {
      'title': 'Why not to burn e-waste?',
      'desc':
          'Burning e-waste releases toxic fumes and heavy metals. Always recycle responsibly.'
    },
    {
      'title': 'Free pickup on Sundays',
      'desc':
          'We offer free home pickup of e-waste on the first Sunday of every month.'
    },
  ];

  void addPost() {
    if (titleController.text.isEmpty || descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter both title and description")),
      );
      return;
    }

    setState(() {
      posts.insert(0, {
        'title': titleController.text,
        'desc': descController.text,
      });
      titleController.clear();
      descController.clear();
    });

    // TODO: Save to Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Post added successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Post Info / Awareness")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: "Post Title"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: descController,
              maxLines: 4,
              decoration: InputDecoration(labelText: "Description"),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: addPost,
              icon: Icon(Icons.post_add),
              label: Text("Post"),
            ),
            SizedBox(height: 20),
            Divider(),
            Expanded(
              child: posts.isEmpty
                  ? Center(child: Text("No posts yet"))
                  : ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(post['title']!),
                            subtitle: Text(post['desc']!),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
