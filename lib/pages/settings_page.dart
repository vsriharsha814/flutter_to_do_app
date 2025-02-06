import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Privacy Policy'),
            leading: const Icon(Icons.privacy_tip),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrivacyPolicyPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.deepPurple,
      ),
      body: const Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            '''Privacy Policy  
            
Last updated: February 06, 2025

This Privacy Policy describes Our policies and procedures on the collection, use, and disclosure of Your information when You use the Service.

1. Information Collection and Use
We only store your task data locally on your device. We do not collect, share, or transmit any personal data to external servers.

2. Data Security  
Since all data is stored locally, you have complete control over your information.

3. Changes to This Policy  
We may update our Privacy Policy from time to time. We will notify you of any changes by updating this page.

4. Contact Us  
If you have any questions, please contact us at srva5218@colorado.edu.
            ''',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}