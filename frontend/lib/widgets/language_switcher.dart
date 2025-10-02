import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showText;
  final MainAxisSize mainAxisSize;

  const LanguageSwitcher({
    Key? key,
    this.showText = true,
    this.mainAxisSize = MainAxisSize.min,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localization, child) {
        if (showText) {
          return Row(
            mainAxisSize: mainAxisSize,
            children: [
              Icon(
                Icons.language,
                size: 20,
                color: Colors.white70,
              ),
              SizedBox(width: 8),
              TextButton(
                onPressed: () => localization.toggleLanguage(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  localization.isThaiLanguage 
                    ? localization.switchToEnglish
                    : localization.switchToThai,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          );
        } else {
          return IconButton(
            onPressed: () => localization.toggleLanguage(),
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 20),
                SizedBox(width: 4),
                Text(
                  localization.currentLanguage.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            tooltip: localization.isThaiLanguage 
              ? localization.switchToEnglish
              : localization.switchToThai,
          );
        }
      },
    );
  }
}

class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localization, child) {
        return PopupMenuButton<String>(
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language),
              SizedBox(width: 4),
              Text(
                localization.currentLanguage.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          onSelected: (languageCode) {
            localization.setLanguage(languageCode);
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'en',
              child: Row(
                children: [
                  Text('🇺🇸'),
                  SizedBox(width: 8),
                  Text(localization.english),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'th',
              child: Row(
                children: [
                  Text('🇹🇭'),
                  SizedBox(width: 8),
                  Text(localization.thai),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
