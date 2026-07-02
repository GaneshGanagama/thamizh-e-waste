// lib/screens/user/reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REVIEWS SCREEN
// • Users can write a review (star rating + comment)
// • All reviews from all users are shown publicly
// • Each user can only submit ONE review (edit/update allowed)
// • Admin can delete any review from the admin dashboard
// • Average star rating shown at the top
// ─────────────────────────────────────────────────────────────────────────────

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _commentCtrl = TextEditingController();
  int    _selectedStars = 5;
  bool   _submitting    = false;
  bool   _showForm      = false;

  // Current user's existing review (if any)
  DocumentSnapshot? _myReview;
  bool _loadingMyReview = true;

  @override
  void initState() {
    super.initState();
    _loadMyReview();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _loadingMyReview = false); return; }
    final snap = await FirebaseFirestore.instance
        .collection('reviews')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty && mounted) {
      final doc  = snap.docs.first;
      final data = doc.data();
      setState(() {
        _myReview     = doc;
        _selectedStars = data['stars'] ?? 5;
        _commentCtrl.text = data['comment'] ?? '';
        _loadingMyReview  = false;
      });
    } else {
      if (mounted) setState(() => _loadingMyReview = false);
    }
  }

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _snack('Please log in to write a review'); return; }
    if (_commentCtrl.text.trim().isEmpty) {
      _snack('Write a comment before submitting'); return;
    }

    setState(() => _submitting = true);
    try {
      final data = {
        'userId':    user.uid,
        'userName':  user.displayName ?? user.email ?? 'User',
        'userEmail': user.email ?? '',
        'stars':     _selectedStars,
        'comment':   _commentCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_myReview != null) {
        // Update existing review
        await _myReview!.reference.update(data);
        _snack('Review updated!');
      } else {
        // New review
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('reviews').add(data);
        _snack('Review submitted! Thank you.');
      }
      setState(() => _showForm = false);
      _loadMyReview();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteMyReview() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete your review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _myReview!.reference.delete();
    setState(() {
      _myReview = null;
      _selectedStars = 5;
      _commentCtrl.clear();
      _showForm = false;
    });
    _snack('Review deleted.');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reviews'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Average rating header ──────────────────────────────────────
          _buildRatingSummary(),

          // ── Write/Edit review button ───────────────────────────────────
          if (user != null && !_loadingMyReview)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _myReview != null
                  ? Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => setState(() => _showForm = !_showForm),
                        icon: Icon(_showForm ? Icons.close : Icons.edit,
                            size: 16),
                        label: Text(_showForm ? 'Cancel' : 'Edit My Review'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green[700]),
                      )),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _deleteMyReview,
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                      ),
                    ])
                  : ElevatedButton.icon(
                      onPressed: () =>
                          setState(() => _showForm = !_showForm),
                      icon: Icon(
                          _showForm ? Icons.close : Icons.rate_review,
                          size: 16),
                      label: Text(_showForm
                          ? 'Cancel'
                          : 'Write a Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
            ),

          // ── Review form ────────────────────────────────────────────────
          if (_showForm) _buildReviewForm(),

          // ── All reviews list ───────────────────────────────────────────
          Expanded(child: _buildReviewsList()),
        ],
      ),
    );
  }

  // ── Average rating banner ──────────────────────────────────────────────────
  Widget _buildRatingSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reviews').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            color: Colors.green[700],
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: const Center(
              child: Text('No reviews yet — be the first!',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          );
        }

        final docs = snap.data!.docs;
        double total = 0;
        final starCounts = [0, 0, 0, 0, 0]; // index 0 = 1 star
        for (final d in docs) {
          final s = (d.data() as Map<String, dynamic>)['stars'] as int? ?? 5;
          total += s;
          if (s >= 1 && s <= 5) starCounts[s - 1]++;
        }
        final avg = total / docs.length;

        return Container(
          color: Colors.green[700],
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(avg.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold)),
              _starRow(avg.round(), size: 20, color: Colors.amber),
              const SizedBox(height: 4),
              Text('${docs.length} review${docs.length == 1 ? "" : "s"}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
            ]),
            const SizedBox(width: 24),
            Expanded(child: Column(
              children: List.generate(5, (i) {
                final star  = 5 - i;
                final count = starCounts[star - 1];
                final frac  = docs.isEmpty ? 0.0 : count / docs.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Text('$star', style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Colors.amber, size: 11),
                    const SizedBox(width: 6),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.amber),
                      ),
                    )),
                    const SizedBox(width: 6),
                    Text('$count', style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
                  ]),
                );
              }),
            )),
          ]),
        );
      },
    );
  }

  // ── Write review form ──────────────────────────────────────────────────────
  Widget _buildReviewForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_myReview != null ? 'Edit Your Review' : 'Write a Review',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),

          // Star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= _selectedStars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          Center(child: Text(_starLabel(_selectedStars),
              style: TextStyle(color: Colors.amber[800], fontSize: 13))),

          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Share your experience with Ecomeel...',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _submitting ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: _submitting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(_myReview != null ? 'Update Review' : 'Submit Review'),
          ),
        ],
      ),
    );
  }

  String _starLabel(int s) {
    switch (s) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return '';
    }
  }

  // ── Reviews list ───────────────────────────────────────────────────────────
  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rate_review, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No reviews yet', style: TextStyle(
                  color: Colors.grey[500], fontSize: 15)),
            ],
          ));
        }

        final myUid = FirebaseAuth.instance.currentUser?.uid;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final name    = data['userName'] ?? 'User';
            final comment = data['comment']  ?? '';
            final stars   = data['stars']    as int? ?? 5;
            final isMe    = data['userId'] == myUid;

            final ts = data['createdAt'];
            String dateStr = '';
            if (ts is Timestamp) {
              dateStr = DateFormat('dd MMM yyyy').format(ts.toDate());
            }

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: isMe ? 2 : 1,
              child: Container(
                decoration: isMe
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.shade300, width: 1.5))
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isMe
                              ? Colors.green[100]
                              : Colors.grey[200],
                          child: Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMe
                                    ? Colors.green[700]
                                    : Colors.grey[700]),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(isMe ? '$name (You)' : name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isMe
                                          ? Colors.green[800]
                                          : Colors.black87)),
                            ]),
                            if (dateStr.isNotEmpty)
                              Text(dateStr,
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500])),
                          ],
                        )),
                        _starRow(stars, size: 14, color: Colors.amber),
                      ]),
                      const SizedBox(height: 8),
                      Text(comment,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _starRow(int count, {double size = 16, Color color = Colors.amber}) =>
      Row(mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) => Icon(
            i < count ? Icons.star : Icons.star_border,
            color: color, size: size)));
}
