import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../download_controller.dart';
import '../utils/formatters.dart';

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _if1Ctrl = TextEditingController();
  final TextEditingController _if2Ctrl = TextEditingController();
  final TextEditingController _fileCtrl = TextEditingController();
 
  final ScrollController _logScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Defaults for testing convenience
    _if1Ctrl.text = "wlan0";
    _if2Ctrl.text = "eth0";
    _fileCtrl.text = "output.bin";
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _if1Ctrl.dispose();
    _if2Ctrl.dispose();
    _fileCtrl.dispose();
    _logScrollCtrl.dispose();
    super.dispose();
  }


  void _scrollToBottom() {
    if (_logScrollCtrl.hasClients) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _logScrollCtrl.animateTo(
          _logScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadControllerProvider);
    final controller = ref.read(downloadControllerProvider.notifier);

    ref.listen(downloadControllerProvider, (previous, next) {
      if (previous?.logs.length != next.logs.length) {
        _scrollToBottom();
      }
      
      if (previous?.isDownloading == true && next.isDownloading == false) {
        if (next.status == AppConstants.statusComplete) {
           _showDialog("Success", "Download completed and verified successfully.");
        } else if (next.status == AppConstants.statusFailed) {
           _showDialog("Error", "Download failed. Check logs for details.");
        }
      }
    });

    final bool isBusy = state.isDownloading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appTitle),
        elevation: 2,
      ),
      body: Column(
        children: [
          // --- Configuration Panel ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildTextField("Download URL:", _urlCtrl, isBusy, hint: "https://..."),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildTextField("Interface 1:", _if1Ctrl, isBusy)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField("Interface 2:", _if2Ctrl, isBusy)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField("Output File:", _fileCtrl, isBusy),
              ],
            ),
          ),

          // --- Controls ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () {
                          if (_validateInputs()) {
                            controller.startDownload(
                              url: _urlCtrl.text.trim(),
                              iface1: _if1Ctrl.text.trim(),
                              iface2: _if2Ctrl.text.trim(),
                              fileName: _fileCtrl.text.trim(),
                            );
                          }
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Start Download"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 48),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isBusy ? controller.stopDownload : null,
                  icon: const Icon(Icons.stop),
                  label: const Text("Stop"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Terminal Log ---
          Expanded(
            child: Container(
              color: const Color(0xFF101010), // Very dark grey/black
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: _logScrollCtrl,
                itemCount: state.logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    state.logs[index],
                    style: GoogleFonts.robotoMono(
                      color: Colors.greenAccent,
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ),
          ),

          // --- Status Bar ---
          Container(
            color: Colors.grey.shade200,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Status: ${state.status}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, bool disabled, {String? hint}) {
    return TextFormField(
      controller: ctrl,
      enabled: !disabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  bool _validateInputs() {
    if (_urlCtrl.text.isEmpty || !_urlCtrl.text.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid HTTP(S) URL')),
      );
      return false;
    }
    if (_fileCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an output filename')),
      );
      return false;
    }
    return true;
  }

  void _showDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }
}