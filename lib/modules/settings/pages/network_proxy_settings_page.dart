import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class NetworkProxySettingsPage extends StatefulWidget {
  const NetworkProxySettingsPage({super.key});

  @override
  State<NetworkProxySettingsPage> createState() => _NetworkProxySettingsPageState();
}

class _NetworkProxySettingsPageState extends State<NetworkProxySettingsPage> {
  final proxyCtrl = SettingsService.to.proxy;

  late final TextEditingController _appHostController;
  late final TextEditingController _appPortController;
  late final TextEditingController _playerHostController;
  late final TextEditingController _playerPortController;

  @override
  void initState() {
    super.initState();
    _appHostController = TextEditingController(text: proxyCtrl.appProxyHost.v);
    _appPortController = TextEditingController(text: proxyCtrl.appProxyPort.v.toString());
    _playerHostController = TextEditingController(text: proxyCtrl.proxyHost.v);
    _playerPortController = TextEditingController(text: proxyCtrl.proxyPort.v.toString());
  }

  @override
  void dispose() {
    _appHostController.dispose();
    _appPortController.dispose();
    _playerHostController.dispose();
    _playerPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("network_proxy_settings"))),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            context.buildGroupTitle(i18n("app_proxy_group_title")),
            context.buildModernCard([
              SwitchListTile(
                secondary: Icon(Remix.apps_line, color: theme.colorScheme.primary),
                title: Text(i18n("enable_app_proxy")),
                subtitle: Text(i18n("enable_app_proxy_desc")),
                value: proxyCtrl.enableAppProxy.v,
                onChanged: (val) => proxyCtrl.enableAppProxy.v = val,
              ),
              if (proxyCtrl.enableAppProxy.v) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _appHostController,
                          decoration: InputDecoration(
                            labelText: i18n("proxy_address_label"),
                            hintText: "127.0.0.1",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) => proxyCtrl.appProxyHost.v = val.trim(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _appPortController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: i18n("proxy_port_label"),
                            hintText: "7890",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final intPort = int.tryParse(val) ?? 1080;
                            proxyCtrl.appProxyPort.v = intPort;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 24),
            context.buildGroupTitle(i18n("player_proxy_group_title")),
            context.buildModernCard([
              SwitchListTile(
                secondary: Icon(Remix.video_line, color: theme.colorScheme.primary),
                title: Text(i18n("enable_player_proxy")),
                subtitle: Text(i18n("enable_player_proxy_desc")),
                value: proxyCtrl.enableProxy.v,
                onChanged: (val) => proxyCtrl.enableProxy.v = val,
              ),
              if (proxyCtrl.enableProxy.v) ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _playerHostController,
                          decoration: InputDecoration(
                            labelText: i18n("proxy_address_label"),
                            hintText: "127.0.0.1",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) => proxyCtrl.proxyHost.v = val.trim(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _playerPortController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: i18n("proxy_port_label"),
                            hintText: "1080",
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final intPort = int.tryParse(val) ?? 1080;
                            proxyCtrl.proxyPort.v = intPort;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 24),
            context.buildGroupTitle(i18n("site_proxy_group_title")),
            context.buildModernCard([
              context.buildTile(
                icon: Remix.image_2_line,
                title: i18n("image_proxy_sites"),
                subtitle: _selectedSitesSubtitle(proxyCtrl.imageProxySites.v),
                onTap: () => _showSiteProxySelector(
                  title: i18n("image_proxy_sites"),
                  description: i18n("image_proxy_sites_desc"),
                  selectedSites: proxyCtrl.imageProxySites,
                ),
              ),
              context.buildTile(
                icon: Remix.cloud_line,
                title: i18n("api_proxy_sites"),
                subtitle: _selectedSitesSubtitle(proxyCtrl.apiProxySites.v),
                onTap: () => _showSiteProxySelector(
                  title: i18n("api_proxy_sites"),
                  description: i18n("api_proxy_sites_desc"),
                  selectedSites: proxyCtrl.apiProxySites,
                ),
              ),
            ]),
            const SizedBox(height: 24),
            context.buildGroupTitle(i18n("ssl_group_title")),
            context.buildModernCard([
              SwitchListTile(
                secondary: Icon(Remix.shield_keyhole_line, color: theme.colorScheme.primary),
                title: Text(i18n("disable_ssl_verify")),
                subtitle: Text(i18n("disable_ssl_verify_desc")),
                value: proxyCtrl.disableSslVerify.v,
                onChanged: (val) => proxyCtrl.disableSslVerify.v = val,
              ),
            ]),
            const SizedBox(height: 32),
          ],
        );
      }),
    );
  }

  String _selectedSitesSubtitle(List<String> selectedIds) {
    if (selectedIds.isEmpty) return i18n("site_proxy_none");
    if (selectedIds.length >= Sites.supportSites.length) return i18n("site_proxy_all");
    return Sites.supportSites
        .where((site) => selectedIds.contains(site.id))
        .map((site) => site.name)
        .join("、");
  }

  Future<void> _showSiteProxySelector({
    required String title,
    required String description,
    required RxList<String> selectedSites,
  }) async {
    await Get.dialog<void>(
      AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Obx(
            () => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description, style: Theme.of(Get.context!).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => selectedSites.v = Sites.supportSites.map((site) => site.id).toList(),
                        child: Text(i18n("select_all")),
                      ),
                      TextButton(
                        onPressed: () => selectedSites.v = [],
                        child: Text(i18n("select_none")),
                      ),
                    ],
                  ),
                  ...Sites.supportSites.map((site) {
                    final selected = selectedSites.contains(site.id);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected,
                      title: Text(site.name),
                      onChanged: (value) {
                        final next = List<String>.from(selectedSites);
                        if (value == true) {
                          if (!next.contains(site.id)) next.add(site.id);
                        } else {
                          next.remove(site.id);
                        }
                        selectedSites.v = next;
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(Get.context!), child: Text(i18n("done"))),
        ],
      ),
    );
  }
}
