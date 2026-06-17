import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/site_account/site_account_controller.dart';

class SiteAccountPage extends GetView<SiteAccountController> {
  const SiteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n('third_party_auth'))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n('third_party_auth')),
          context.buildModernCard(
            controller.sites.map((site) {
              if (!site.liveSite.isSupportLogin()) {
                return _buildAccountTile(
                  context,
                  logo: site.logo,
                  title: site.name,
                  subtitle: i18n('not_supported'),
                  isLogined: false,
                  isEnabled: false,
                  onTap: () {},
                );
              }

              return Obx(
                () => _buildAccountTile(
                  context,
                  logo: site.logo,
                  title: site.name,
                  subtitle: site.liveSite.isLogin.value
                      ? (site.liveSite.userName.value.isNotEmpty ? site.liveSite.userName.value : i18n('logined'))
                      : i18n('not_logged_in'),
                  isLogined: site.liveSite.isLogin.value,
                  onTap: () => controller.onTap(site),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context, {
    required String logo,
    required String title,
    required String subtitle,
    required bool isLogined,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      enabled: isEnabled,
      leading: Image.asset(logo, width: 24, height: 24),
      title: Text(
        title,
        style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600, color: isEnabled ? null : theme.disabledColor),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: AppTextStyles.t12.copyWith(
            color: isLogined ? theme.colorScheme.primary : theme.hintColor.withValues(alpha: 0.75),
            fontWeight: isLogined ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: isLogined
          ? Icon(Remix.logout_box_r_line, color: theme.colorScheme.error.withValues(alpha: 0.8), size: 18)
          : Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}
