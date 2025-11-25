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
  final TextEditingController _if1Ctrl = TextEditingController(text: "Wi-Fi");
  final TextEditingController _if2Ctrl = TextEditingController(text: "Cellular");
  final TextEditingController _fileCtrl = TextEditingController(text: "large_file.zip");
  final ScrollController _logScrollCtrl = ScrollController();

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
    final isBusy = state.isDownloading;

    ref.listen(downloadControllerProvider, (prev, next) {
      if (prev?.logs.length != next.logs.length) _scrollToBottom();
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            _buildHeader(),

            // --- Main Content ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Configuration Card
                  _buildConfigCard(isBusy),

                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: "Initialize Stream",
                          icon: Icons.bolt,
                          color: const Color(0xFF10B981), // Emerald
                          onPressed: isBusy
                              ? null
                              : () {
                                  if (_urlCtrl.text.isEmpty) return;
                                  controller.startDownload(
                                    url: _urlCtrl.text.trim(),
                                    iface1: _if1Ctrl.text,
                                    iface2: _if2Ctrl.text,
                                    fileName: _fileCtrl.text,
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          label: "Abort",
                          icon: Icons.stop_circle_outlined,
                          color: const Color(0xFFEF4444), // Red
                          onPressed: isBusy ? controller.stopDownload : null,
                          isOutlined: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Terminal Window
                  _buildTerminalWindow(state.logs),
                ],
              ),
            ),

            // --- Status Footer ---
            _buildStatusBar(state.status),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MultiNet Monitor",
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                "Active Multipath Engine",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(bool isBusy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "CONFIGURATION",
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildInput(_urlCtrl, "Target URL", Icons.link, isBusy),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInput(_if1Ctrl, "Interface A", Icons.wifi, isBusy)),
              const SizedBox(width: 12),
              Expanded(child: _buildInput(_if2Ctrl, "Interface B", Icons.cell_tower, isBusy)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInput(_fileCtrl, "Output Filename", Icons.save_alt, isBusy),
        ],
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String label,
    IconData icon,
    bool disabled,
  ) {
    return TextField(
      controller: controller,
      enabled: !disabled,
      style: GoogleFonts.jetBrainsMono(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isOutlined = false,
  }) {
    final isDisabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDisabled
                ? const Color(0xFF334155).withOpacity(0.5)
                : isOutlined
                    ? Colors.transparent
                    : color,
            borderRadius: BorderRadius.circular(12),
            border: isOutlined && !isDisabled
                ? Border.all(color: color.withOpacity(0.5), width: 1.5)
                : null,
            boxShadow: !isDisabled && !isOutlined
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isDisabled
                    ? Colors.white.withOpacity(0.2)
                    : isOutlined
                        ? color
                        : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: isDisabled
                      ? Colors.white.withOpacity(0.2)
                      : isOutlined
                          ? color
                          : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalWindow(List<String> logs) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117), // Deep black/blue
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Terminal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Text(
                  "LIVE LOG STREAM",
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _buildDot(const Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    _buildDot(const Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    _buildDot(const Color(0xFF10B981)),
                  ],
                )
              ],
            ),
          ),
          // Log List
          Expanded(
            child: ListView.builder(
              controller: _logScrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                // Simple color coding based on keywords
                Color logColor = const Color(0xFF94A3B8);
                if (log.contains("SUCCESS") || log.contains("Complete")) {
                  logColor = const Color(0xFF34D399);
                } else if (log.contains("Error") || log.contains("Failed")) {
                  logColor = const Color(0xFFF87171);
                } else if (log.contains("WARNING")) {
                  logColor = const Color(0xFFFBBF24);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    log,
                    style: GoogleFonts.jetBrainsMono(
                      color: logColor,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatusBar(String status) {
    Color statusColor = const Color(0xFF94A3B8);
    // ignore: unused_local_variable
    IconData statusIcon = Icons.circle_outlined;

    if (status == AppConstants.statusDownloading) {
      statusColor = const Color(0xFF38BDF8);
      statusIcon = Icons.sync;
    } else if (status == AppConstants.statusComplete) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle;
    } else if (status == AppConstants.statusFailed) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}