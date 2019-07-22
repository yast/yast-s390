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
Version:        4.0.6
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:		System/YaST
License:        GPL-2.0
BuildRequires:	yast2
BuildRequires:	yast2-devtools
BuildRequires:	yast2-ruby-bindings >= 3.1.7
BuildRequires:  rubygem(%rb_default_ruby_abi:rspec)
BuildRequires:  rubygem(%rb_default_ruby_abi:yast-rake)
BuildRequires:	update-desktop-files

# Y2Storage::Inhibitors
BuildRequires: yast2-storage-ng >= 4.0.175
Requires:      yast2-storage-ng >= 4.0.175

ExclusiveArch:  s390 s390x
Requires:	yast2
Requires:	yast2-ruby-bindings >= 3.1.7
Requires:	s390-tools
Supplements:	yast2-storage-ng
Summary:	YaST2 - S/390 Specific Features Configuration
Url:		http://github.com/yast/yast-s390/

%description
This package contains the YaST component for configuration of
S/390-specific features.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"

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
