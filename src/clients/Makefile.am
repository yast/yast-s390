# Makefile.am for zfcp/src

yncludedir = @yncludedir@/s390/zfcp

client_DATA =			\
	zfcp.ycp		\
	zfcp_auto.ycp		\
	dasd.ycp		\
	dasd_auto.ycp		\
	s390-disk-controller.ycp\
	xpram.ycp		\
	dump.ycp		\
	inst_dasd.ycp		\
	inst_zfcp.ycp		\
	dasd_proposal.ycp	\
	zfcp_proposal.ycp

desktop_DATA =			\
	zfcp.desktop		\
	dasd.desktop		\
	xpram.desktop		\
	dump.desktop


EXTRA_DIST = $(client_DATA) $(desktop_DATA)

include $(top_srcdir)/Makefile.am.common
