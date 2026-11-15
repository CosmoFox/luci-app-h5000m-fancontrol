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

# Embed every translation catalog into the main package so users do not need
# the separate luci-i18n-* packages. Languages are discovered from po/* -
# the same wildcard convention luci.mk uses for its translation packages -
# so adding a language only requires its po/<lang> directory; nothing here
# needs editing. zh_Hans maps to the zh-cn package code, other codes pass
# through unchanged.
H5FAN_PO_LANGS := $(filter-out templates,$(notdir $(wildcard $(CURDIR)/po/*)))

define Package/luci-app-h5000m-fancontrol/install
	$(call Package/luci-app-h5000m-fancontrol/install/template,$(1))
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(foreach lang,$(H5FAN_PO_LANGS),po2lmo ./po/$(lang)/h5000m-fancontrol.po $(1)/usr/lib/lua/luci/i18n/h5000m-fancontrol.$(subst zh_Hans,zh-cn,$(lang)).lmo;)
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
