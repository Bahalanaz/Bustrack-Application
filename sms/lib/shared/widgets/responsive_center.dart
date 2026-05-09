import 'package:flutter/material.dart';

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  // 600 pixels is a standard "Tablet/Mobile" max width
  final double maxWidth; 

  const ResponsiveCenter({
    super.key, 
    required this.child, 
    this.maxWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Center puts it in the middle of the monitor
    return Center(
      // 2. ConstrainedBox stops it from stretching too wide
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}