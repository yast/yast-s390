#
# spec file for package yast2-s390
#
# Copyright (c) 2014 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-s390
Version:        3.1.27
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:		System/YaST
License:        GPL-2.0
BuildRequires:	docbook-xsl-stylesheets update-desktop-files
BuildRequires:	yast2 yast2-testsuite
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:	yast2-ruby-bindings >= 3.1.7
BuildRequires:  rubygem(rspec)
ExclusiveArch:  s390 s390x
Requires:	yast2
Requires:	yast2-ruby-bindings >= 3.1.7
Requires:	s390-tools
Summary:	YaST2 - S/390 Specific Features Configuration
Url:		http://github.com/yast/yast-s390/

%description
This package contains the YaST component for configuration of
S/390-specific features.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/s390
%{yast_yncludedir}/s390/*
%{yast_clientdir}/*.rb
%{yast_moduledir}/*
%{yast_scrconfdir}/*.scr
%{yast_desktopdir}/*.desktop
%{yast_schemadir}/autoyast/rnc/*.rnc
%doc %{yast_docdir}
