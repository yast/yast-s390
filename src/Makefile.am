# Sources for s390

module_DATA = \
  modules/DASDController.rb \
  modules/Xpram.rb \
  modules/ZFCPController.rb \
  modules/IUCVTerminal.rb \
  modules/IUCVTerminalServer.rb \
  modules/OnPanic.rb \
  modules/Dump.rb

client_DATA = \
  clients/s390-disk-controller.rb \
  clients/onpanic.rb \
  clients/inst_dasd.rb \
  clients/dasd_auto.rb \
  clients/iucvterminal.rb \
  clients/dasd.rb \
  clients/dump.rb \
  clients/zfcp.rb \
  clients/zfcp_auto.rb \
  clients/zfcp_proposal.rb \
  clients/dasd_proposal.rb \
  clients/iucvterminal-server.rb \
  clients/inst_zfcp.rb \
  clients/xpram.rb

yncludedir = @yncludedir@/s390/zfcp
ynclude_DATA = \
  include/s390/zfcp/wizards.rb \
  include/s390/zfcp/dialogs.rb \
  include/s390/zfcp/helps.rb

ynclude1dir = @yncludedir@/s390/xpram
ynclude1_DATA = \
  include/s390/xpram/ui.rb

ynclude2dir = @yncludedir@/s390/dump
ynclude2_DATA = \
  include/s390/dump/ui.rb

ynclude3dir = @yncludedir@/s390/iucvterminal-server
ynclude3_DATA = \
  include/s390/iucvterminal-server/ui.rb \
  include/s390/iucvterminal-server/helps.rb

ynclude4dir = @yncludedir@/s390/onpanic
ynclude4_DATA = \
  include/s390/onpanic/ui.rb

ynclude5dir = @yncludedir@/s390/iucvterminal
ynclude5_DATA = \
  include/s390/iucvterminal/ui.rb

ynclude6dir = @yncludedir@/s390/dasd
ynclude6_DATA = \
  include/s390/dasd/wizards.rb \
  include/s390/dasd/dialogs.rb \
  include/s390/dasd/helps.rb

scrconf_DATA = \
  scrconf/cfg_xpram.scr \
  scrconf/cfg_iucv_terminal_server.scr \
  scrconf/etc_iucv_ts-authorization.scr \
  scrconf/cfg_dumpconf.scr

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/dasd.rnc \
  autoyast-rnc/zfcp.rnc

desktop_DATA = \
  desktop/onpanic.desktop \
  desktop/dasd.desktop \
  desktop/dump.desktop \
  desktop/iucvterminal.desktop \
  desktop/iucvterminal-server.desktop \
  desktop/xpram.desktop \
  desktop/zfcp.desktop

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(ynclude1_DATA) $(ynclude2_DATA) $(ynclude3_DATA) $(ynclude4_DATA) $(ynclude5_DATA) $(ynclude6_DATA) $(scrconf_DATA) $(schemafiles_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common