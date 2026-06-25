import 'package:flutter/material.dart';
import '../services/webdav_client.dart';
import '../services/cookie_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootDirController = TextEditingController(text: '/TTshare');
  final _webdavClient = WebdavClient();
  final _cookieManager = CookieManager();
  bool _isVerifying = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await _webdavClient.loadConfig();
    setState(() {
      _urlController.text = '';
      _usernameController.text = '';
      _passwordController.text = '';
    });
  }

  Future<void> _verifyConnection() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (url.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写完整的 WebDAV 配置')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    await _webdavClient.saveConfig(url, username, password);
    final ok = await _webdavClient.verifyConnection();

    setState(() => _isVerifying = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '✅ 连接成功' : '❌ 连接失败，请检查配置'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // WebDAV Config Section
          const Text(
            '📁 WebDAV 配置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '服务器 URL',
              hintText: 'https://dav.jianguoyun.com/dav',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: 'your@email.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: '密码/应用密码',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_showPassword
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rootDirController,
            decoration: const InputDecoration(
              labelText: '根目录',
              hintText: '/TTshare',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isVerifying ? null : _verifyConnection,
            icon: _isVerifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_isVerifying ? '验证中...' : '验证连接'),
          ),

          const SizedBox(height: 32),
          const Divider(),

          // Cookie Management Section
          const Text(
            '🍪 Cookie 管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _cookieManager.getAllCookies(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text(
                  '暂无已保存的 Cookie',
                  style: TextStyle(color: Colors.grey),
                );
              }
              final cookies = snapshot.data!;
              return Column(
                children: [
                  for (final cookie in cookies)
                    ListTile(
                      leading: const Icon(Icons.language, size: 20),
                      title: Text(cookie.domain),
                      trailing: const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                      dense: true,
                      onTap: () async {
                        await _cookieManager.clearDomain(cookie.domain);
                        setState(() {});
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('已清除 ${cookie.domain} 的 Cookie')),
                        );
                      },
                    ),
                ],
              );
            },
          ),
          TextButton.icon(
            onPressed: () async {
              await _cookieManager.clearAll();
              setState(() {});
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清除所有 Cookie')),
              );
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('清除所有 Cookie',
                style: TextStyle(color: Colors.red)),
          ),

          const SizedBox(height: 32),
          const Divider(),

          // About
          const Text(
            'ℹ️ 关于',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('TTshare v1.0.0'),
          const Text(
            '网页快照保存工具',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootDirController.dispose();
    super.dispose();
  }
}
