include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-h5000m-fancontrol
PKG_VERSION:=2.3.2
PKG_RELEASE:=1
PKG_PO_VERSION:=$(PKG_VERSION)-r$(PKG_RELEASE)
PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=LICENSE

LUCI_TITLE:=H5000M fan control
LUCI_DEPENDS:=+luci-base +kmod-hwmon-pwmfan
LUCI_PKGARCH:=all

define Package/luci-app-h5000m-fancontrol/conffiles
/etc/config/h5000m_fancontrol
endef

include $(TOPDIR)/feeds/luci/luci.mk

# Embed every translation catalog into the main package so users do not need
# the separate luci-i18n-* packages. This define MUST come after the luci.mk
# include: luci.mk sets Package/<name>/install to the default template, and
# a define placed before the include would be overwritten. Languages are
# discovered from po/* at install time, so a new language only requires its
# po/<lang> directory; zh_Hans maps to the zh-cn package code, others pass
# through. A po2lmo failure aborts the build instead of shipping silently
# untranslated.
define Package/luci-app-h5000m-fancontrol/install
	$(call Package/luci-app-h5000m-fancontrol/install/template,$(1))
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	for po in ./po/*/*.po; do \
		[ -f "$$po" ] || continue; \
		lang=$${po#./po/}; lang=$${lang%%/*}; \
		[ "$$lang" = "templates" ] && continue; \
		code=$$(printf '%s' "$$lang" | sed 's/^zh_Hans$$/zh-cn/'); \
		po2lmo "$$po" "$(1)/usr/lib/lua/luci/i18n/h5000m-fancontrol.$$code.lmo" || exit 1; \
	done
endef

# call BuildPackage - OpenWrt buildroot signature
