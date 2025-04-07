import 'package:flutter/material.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class AuthAlert {
  final String title;
  final String description;
  final AlertType type;

  const AuthAlert({
    required this.title,
    required this.description,
    required this.type,
  });

  void show(BuildContext context) {
    Alert(
      context: context,
      style: alertStyle,
      type: type,
      title: title,
      desc: description,
      buttons: [
        DialogButton(
          onPressed: () => Navigator.pop(context),
          color: type == AlertType.success
              ? const Color.fromRGBO(0, 179, 134, 1.0)
              : Colors.red,
          radius: BorderRadius.circular(0.0),
          child: const Text(
            "OK",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ],
    ).show();
  }
}

var alertStyle = AlertStyle(
  animationType: AnimationType.fromTop,
  isCloseButton: true,
  isOverlayTapDismiss: true,
  descStyle: const TextStyle(fontWeight: FontWeight.bold),
  animationDuration: const Duration(milliseconds: 400),
  alertBorder: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10.0),
    side: const BorderSide(
      color: Colors.grey,
    ),
  ),
  titleStyle: const TextStyle(
    color: Colors.red,
  ),
);
