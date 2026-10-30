
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

void main() => runApp(const PasswordResetApp());

class PasswordResetApp extends StatelessWidget {
  const PasswordResetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Password Reset Request Workflow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF1493),
        ),
        primaryColor: const Color(0xFFFF1493),
        scaffoldBackgroundColor: const Color(0xFFFFF5FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF1493),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      home: const ResetDashboard(),
    );
  }
}

enum DeliveryScenario { normal, transient, permanent }

class ResetRequest {
  ResetRequest({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.deliveryStatus,
  });

  final String id;
  final String email;
  final DateTime createdAt;
  final DateTime expiresAt;
  String status;
  String deliveryStatus;
}

class AuditEntry {
  AuditEntry(this.time, this.event, this.requestId, this.result);

  final DateTime time;
  final String event;
  final String requestId;
  final String result;

  Map<String, dynamic> toJson() => {
        'timestamp': time.toIso8601String(),
        'event': event,
        'request_id': requestId,
        'result': result,
      };
}

class ResetDashboard extends StatefulWidget {
  const ResetDashboard({super.key});

  @override
  State<ResetDashboard> createState() => _ResetDashboardState();
}

class _ResetDashboardState extends State<ResetDashboard> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  final List<ResetRequest> _requests = [];
  final List<AuditEntry> _logs = [];

  DeliveryScenario _scenario = DeliveryScenario.normal;
  bool _busy = false;

  String _notice =
      'Use fictional email addresses only. This Week 13 prototype does not reset passwords or send real messages.';

  void _log(String event, String id, String result) {
    _logs.insert(0, AuditEntry(DateTime.now(), event, id, result));
  }

  String _newId() => 'PR-${DateTime.now().millisecondsSinceEpoch}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    // One request per email within a 60-second window.
    final recent = _requests.where(
      (r) =>
          r.email == email &&
          DateTime.now().difference(r.createdAt).inSeconds < 60,
    );

    if (recent.isNotEmpty) {
      setState(() {
        _notice =
            'Request limited: a request for this address was already created in the last 60 seconds.';
        _log('request.rate_limited', recent.first.id, 'blocked');
      });
      return;
    }

    setState(() {
      _busy = true;
      _notice = 'Submitting request...';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    final id = _newId();

    final request = ResetRequest(
      id: id,
      email: email,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      status: 'Verification handoff pending',
      deliveryStatus: 'Queued',
    );

    setState(() {
      _requests.insert(0, request);

      _log(
        'reset.request_created',
        id,
        'accepted; no password content stored',
      );

      _log(
        'identity.verification_handoff',
        id,
        'pending authorized verification',
      );
    });

    // Simulate a temporary delivery failure and one retry.
    if (_scenario == DeliveryScenario.transient) {
      setState(() {
        request.deliveryStatus = 'Retrying (attempt 1 of 2)';
        _log(
          'notification.delivery_attempt',
          id,
          'temporary service error',
        );
      });

      await Future.delayed(const Duration(milliseconds: 450));

      setState(() {
        request.deliveryStatus = 'Delivered after retry';

        _log(
          'notification.delivery_retry',
          id,
          'recovered on attempt 2',
        );

        _notice =
            'Request created. Simulated temporary delivery failure recovered on the second attempt.';
      });
    } else if (_scenario == DeliveryScenario.permanent) {
      setState(() {
        request.deliveryStatus = 'Manual review required';
        request.status = 'Delivery exception – human action required';

        _log(
          'notification.delivery_failed',
          id,
          'permanent failure; retries stopped',
        );

        _log(
          'workflow.manual_review',
          id,
          'routed to authorized help-desk staff',
        );

        _notice =
            'Request created, but notification delivery failed permanently. It has been routed for human review.';
      });
    } else {
      setState(() {
        request.deliveryStatus = 'Delivered (simulated)';

        _log(
          'notification.delivery',
          id,
          'simulated success',
        );

        _notice =
            'Request created. Identity verification is pending; no password has been changed.';
      });
    }

    setState(() {
      _busy = false;
    });
  }

  void _runExpiryCheck() {
    var expiredCount = 0;

    for (final r in _requests) {
      if (DateTime.now().isAfter(r.expiresAt) &&
          r.status != 'Closed – expired') {
        r.status = 'Closed – expired';
        expiredCount++;

        _log(
          'reset.request_expired',
          r.id,
          'closed automatically after 15 minutes',
        );
      }
    }

    setState(() {
      _notice = expiredCount == 0
          ? 'Expiry check complete: no requests required closure.'
          : 'Expiry check complete: $expiredCount request(s) closed as expired.';
    });
  }

  void _markAuthorizedAction(ResetRequest r) {
    setState(() {
      r.status = 'Authorized action recorded – awaiting notification';

      _log(
        'identity.authorized_action_recorded',
        r.id,
        'help-desk action recorded; password not handled by this prototype',
      );

      _notice =
          'Authorized action recorded for ${r.id}. This prototype does not set or store a password.';
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Reset Request Workflow'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          final form = _buildRequestPanel();
          final queue = _buildQueuePanel();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: const Color(0xFFFFD6E7),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFFFF1493),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'WEEK 13 SA7 DEMONSTRATION • Fictional data only. This is a workflow prototype, not a production password-reset service. Never enter a real password or use real account data.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _notice,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFAD1457),
                  ),
                ),
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: form),
                      const SizedBox(width: 16),
                      Expanded(child: queue),
                    ],
                  )
                else ...[
                  form,
                  const SizedBox(height: 16),
                  queue,
                ],
                const SizedBox(height: 16),
                _buildLogPanel(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestPanel() => Card(
        color: const Color(0xFFFFE4EF),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create reset request',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFFF1493),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Account email (fictional test address)',
                    hintText: 'student@example.test',
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Color(0xFFFF1493),
                        width: 2,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final value = (v ?? '').trim();

                    if (value.isEmpty) {
                      return 'Email is required.';
                    }

                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value)) {
                      return 'Enter a valid email format.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DeliveryScenario>(
                  initialValue: _scenario,
                  decoration: const InputDecoration(
                    labelText: 'Notification simulation scenario',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DeliveryScenario.normal,
                      child: Text('Normal delivery'),
                    ),
                    DropdownMenuItem(
                      value: DeliveryScenario.transient,
                      child: Text('Temporary failure, then recovery'),
                    ),
                    DropdownMenuItem(
                      value: DeliveryScenario.permanent,
                      child: Text('Permanent failure → manual review'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _scenario = v ?? DeliveryScenario.normal;
                    });
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1493),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(15),
                    ),
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _busy ? 'Submitting...' : 'Submit reset request',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Controls: email-format validation, 60-second duplicate-request cooldown, 15-minute request expiry, bounded notification retry, and manual review for permanent failure.',
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildQueuePanel() => Card(
        color: const Color(0xFFFFE4EF),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request queue',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFFFF1493),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('${_requests.length} request(s)')),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1493),
                    ),
                    onPressed: _runExpiryCheck,
                    icon: const Icon(Icons.timer_off),
                    label: const Text('Run expiry check'),
                  ),
                ],
              ),
              const Divider(),
              if (_requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'No requests yet. Submit a fictional test request.',
                  ),
                )
              else
                ..._requests.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5FA),
                      border: Border.all(
                        color: const Color(0xFFFF69B4),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF1493),
                          ),
                        ),
                        Text(r.email),
                        const SizedBox(height: 4),
                        Text('Workflow: ${r.status}'),
                        Text('Notification: ${r.deliveryStatus}'),
                        Text('Expires: ${r.expiresAt.toLocal()}'),
                        if (r.status.startsWith('Delivery exception'))
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFFF1493),
                              ),
                              onPressed: () => _markAuthorizedAction(r),
                              icon: const Icon(Icons.support_agent),
                              label: const Text('Record help-desk action'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildLogPanel() => Card(
        color: const Color(0xFFFFE4EF),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Structured audit log',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFFFF1493),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1493),
                    ),
                    onPressed: _logs.isEmpty
                        ? null
                        : () {
                            final content = const JsonEncoder.withIndent('  ')
                                .convert(
                              _logs.map((e) => e.toJson()).toList(),
                            );

                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('JSON audit log'),
                                content: SingleChildScrollView(
                                  child: SelectableText(content),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                    icon: const Icon(Icons.data_object),
                    label: const Text('View JSON'),
                  ),
                  const SizedBox(width: 8),
                  Text('${_logs.length} event(s)'),
                ],
              ),
              const Divider(),
              if (_logs.isEmpty)
                const Text('No audit events recorded yet.')
              else
                ..._logs.take(12).map(
                      (e) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.receipt_long,
                          color: Color(0xFFFF1493),
                        ),
                        title: Text(e.event),
                        subtitle: Text('${e.requestId} • ${e.result}'),
                        trailing: Text(
                          e.time.toLocal().toString().substring(11, 19),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
}
