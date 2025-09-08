import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightGreen[700],
        title: const Text('Thamizh E-Waste'),
        actions: [
          IconButton(
            icon: const Icon(Icons.contact_phone),
            onPressed: () => Navigator.pushNamed(context, '/contact'),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔁 Large Image Slider
            SizedBox(
              height: isMobile ? 220 : 360,
              child: PageView(
                controller: PageController(viewportFraction: 0.9),
                children: [
                  _carouselImage('assets/images/THAMIZH-01.jpg'),
                  _carouselImage('assets/images/THAMIZH-02.jpg'),
                  _carouselImage('assets/images/THAMIZH-03.jpg'),
                  _carouselImage('assets/images/THAMIZH-03B.jpg'),
                  _carouselImage('assets/images/THAMIZH-04.jpg'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🟩 Compact Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isMobile ? 2 : 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _gridButton(context, Icons.recycling, 'Pickup', '/pickup'),
                  _gridButton(
                      context, Icons.location_on, 'Drop Points', '/dropoff'),
                  _gridButton(context, Icons.calculate, 'Rewards', '/rewards'),
                  _gridButton(context, Icons.picture_as_pdf, 'Certificate',
                      '/certificate'),
                  _gridButton(
                      context, Icons.history, 'Submissions', '/history'),
                  _gridButton(
                      context, Icons.campaign, 'Awareness', '/info_posts'),
                  _gridButton(context, Icons.person_add, 'Join Us',
                      '/register_recycler'),
                  _gridButton(
                      context, Icons.contact_phone, 'Contact', '/contact'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 🌱 Impact Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Colors.green[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('♻️ 1.2 Tons of e-waste recycled',
                          style: TextStyle(fontSize: 16)),
                      SizedBox(height: 6),
                      Text('🌳 Estimated 40 trees saved'),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _carouselImage(String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            path,
            fit: BoxFit.contain, // 👈 prevents cropping
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }

  //Widget _carouselImage(String path) {
  //return Padding(
  //padding: const EdgeInsets.symmetric(horizontal: 6),
  //child: ClipRRect(
  //borderRadius: BorderRadius.circular(16),
  //child: Image.asset(
  //path,
  //fit: BoxFit.cover,
  // ),
  // ),
  //);
  //}

  Widget _gridButton(
      BuildContext context, IconData icon, String label, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: Colors.green[800]),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
