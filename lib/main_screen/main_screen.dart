import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wildhack/constants/colors.dart';
import 'package:wildhack/main_screen/app_provider.dart';
import 'package:wildhack/main_screen/components/files_uploading.dart';
import 'package:wildhack/main_screen/components/files_view_widget.dart';
import 'package:wildhack/main_screen/components/folders_widget.dart';
import 'package:wildhack/main_screen/components/statistic.dart';

import 'components/side_menu.dart';

// ignore: use_key_in_widget_constructors
class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appProvider = Provider.of<AppProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.lightBlue,
      // drawer: const SideMenu(),
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 2,
                  child: SideMenu(),
                ),
                Expanded(
                  flex: 8,
                  child: appProvider.filesWithoutAnimal.isEmpty
                      ? const FilesUploading()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 30),
                            Expanded(
                              child: FilesViewWidget(
                                title: 'Загруженные файлы',
                                files: appProvider.filesWithoutAnimal,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Expanded(
                              child: FilesViewWidget(
                                title: 'Загруженные файлы',
                                files: appProvider.filesWithoutAnimal,
                                withFolders: true,
                                dragNDropOn: false,
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                ),
                appProvider.filesWithoutAnimal.isEmpty
                    ? Container()
                    : const Expanded(
                        flex: 3,
                        child: Statistics(),
                      ),
              ],
            ),
            // Container(
            //   width: double.infinity,
            //   height: double.infinity,
            //   color: AppColors.black.withOpacity(0.8),
            //   child: Center(
            //     child: ClipRRect(
            //       borderRadius: BorderRadius.circular(20),
            //       child: Container(
            //           height: 120,
            //           width: 160,
            //           decoration: BoxDecoration(
            //               color: AppColors.lightBlue,
            //               borderRadius: BorderRadius.circular(20)),
            //           child: Column(
            //             children: [
            //               Image.file(
            //                 File(appProvider.filesWithoutAnimal[0].path),
            //               ),
            //             ],
            //           )),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
