import 'package:flutter/material.dart';

void main() {
  runApp(const WhatsAppClone());
}

class WhatsAppClone extends StatelessWidget {
  const WhatsAppClone({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WhatsApp Clone',
      theme: ThemeData(
        primaryColor: const Color(0xff075E54),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final pages = [
    const ChatsPage(),
    const StatusPage(),
    const AccountPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff075E54),
        title: const Text("WhatsApp"),
        actions: const [
          Icon(Icons.search),
          SizedBox(width: 15),
          Icon(Icons.more_vert),
          SizedBox(width: 10),
        ],
      ),
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xff25D366),
        unselectedItemColor: Colors.grey,
        onTap: (value) {
          setState(() {
            currentIndex = value;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: "Chats",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.circle_outlined),
            label: "Story",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Account",
          ),
        ],
      ),
    );
  }
}

//////////////////// CHAT PAGE ////////////////////

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  final List<Map<String, String>> chats = const [
    {
      "name": "Rahul",
      "message": "Hey bro!",
      "time": "10:45 AM",
      "image":
          "https://i.pravatar.cc/150?img=1"
    },
    {
      "name": "Priya",
      "message": "Where are you?",
      "time": "09:20 AM",
      "image":
          "https://i.pravatar.cc/150?img=2"
    },
    {
      "name": "Aman",
      "message": "Let's meet today",
      "time": "Yesterday",
      "image":
          "https://i.pravatar.cc/150?img=3"
    },
    {
      "name": "Neha",
      "message": "Good morning 😊",
      "time": "Yesterday",
      "image":
          "https://i.pravatar.cc/150?img=4"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];

        return ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(chat["image"]!),
          ),
          title: Text(
            chat["name"]!,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(chat["message"]!),
          trailing: Text(
            chat["time"]!,
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}

//////////////////// STORY PAGE ////////////////////

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  final List<String> names = const [
    "Rahul",
    "Priya",
    "Aman",
    "Neha",
    "Vikas",
    "Simran"
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ListTile(
          leading: CircleAvatar(
            radius: 28,
            child: Icon(Icons.add),
          ),
          title: Text(
            "My Story",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text("Tap to add story"),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "Recent Updates",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ...names.map((name) {
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: CircleAvatar(
                radius: 26,
                child: Text(name[0]),
              ),
            ),
            title: Text(name),
            subtitle: const Text("Today, 9:00 AM"),
          );
        }).toList(),
      ],
    );
  }
}

//////////////////// ACCOUNT PAGE ////////////////////

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 20),
        CircleAvatar(
          radius: 45,
          backgroundImage:
              NetworkImage("https://i.pravatar.cc/150?img=10"),
        ),
        SizedBox(height: 10),
        Center(
          child: Text(
            "Your Name",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Center(
          child: Text(
            "+91 9876543210",
            style: TextStyle(color: Colors.grey),
          ),
        ),
        SizedBox(height: 30),
        ListTile(
          leading: Icon(Icons.person),
          title: Text("Profile"),
        ),
        ListTile(
          leading: Icon(Icons.lock),
          title: Text("Privacy"),
        ),
        ListTile(
          leading: Icon(Icons.notifications),
          title: Text("Notifications"),
        ),
        ListTile(
          leading: Icon(Icons.help),
          title: Text("Help"),
        ),
      ],
    );
  }
}