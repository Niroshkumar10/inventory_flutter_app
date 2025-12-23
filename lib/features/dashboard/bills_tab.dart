import 'package:flutter/material.dart';

class BillsTab extends StatelessWidget {
  final String userMobile;

  const BillsTab({Key? key, required this.userMobile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Bills Screen'),
    );
  }
}
