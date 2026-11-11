%global srcname   setmy-info-elixir
%global smi       /opt/setmy.info
%global lib       %{smi}/lib/elixir
%global unit      setmy-info-elixir@.service
# The apps this environment serves, one setmy-info-elixir@<app>.service each.
%global services  demo_module_a demo_module_b demo_module_c demo_module_d

# The apps are compiled by rpm/Makefile with mix, before rpmbuild; packaged as they are.
%global debug_package %{nil}
%global __os_install_post %{nil}

Name:           setmy-info-elixir
Version:        %{smi_version}
Release:        %{smi_release}
Summary:        setmy.info Elixir software, LIVE machine

License:        MIT
Vendor:         Hear And See Systems OÜ
URL:            https://setmy.info
Source0:        %{srcname}-%{version}.tar.gz

BuildArch:      noarch
AutoReqProv:    no
Conflicts:      setmy-info-elixir-test

%description
The compiled apps of the setmy.info-elixir umbrella on the LIVE
machines. It runs on the Erlang installed on the machine, /opt/erlang, as the
user microservice of setmy-info-scripts.

  /opt/setmy.info/lib/elixir/modules/<app>/{ebin,priv}   the apps and their libraries
  /opt/setmy.info/lib/elixir/config                      their configuration
  /opt/setmy.info/bin/smi-elixir-start                   starts an app (the service)
  /opt/setmy.info/bin/smi-demo-module-a                  a CLI tool
  /opt/setmy.info/etc/elixir/elixir.env                  every machine
  /opt/setmy.info/etc/elixir/machine.env                 this environment: machine-live.env
  /opt/setmy.info/etc/systemd/system/%{unit}  one service per app

Every install enables and restarts setmy-info-elixir@<app> for %{services}.
/opt/setmy.info/etc/elixir/local.env, made by hand, overrides both env files.

The TEST machines take setmy-info-elixir-test instead; the two conflict.

%prep
%autosetup -n %{srcname}-%{version}

%build

%install
install -d %{buildroot}%{lib} %{buildroot}%{smi}/bin %{buildroot}%{smi}/etc/elixir \
    %{buildroot}%{smi}/etc/systemd/system %{buildroot}%{_sysconfdir}/systemd/system \
    %{buildroot}/var/opt/setmy.info/elixir/tmp
cp -a modules config %{buildroot}%{lib}/
install -m 0644 LICENSE %{buildroot}%{lib}/
install -m 0755 src/main/sh/bin/smi-elixir-start src/main/sh/bin/smi-demo-module-a %{buildroot}%{smi}/bin/
install -m 0644 src/main/sh/etc/elixir/elixir.env %{buildroot}%{smi}/etc/elixir/
install -m 0644 src/main/sh/etc/elixir/machine-live.env %{buildroot}%{smi}/etc/elixir/machine.env
install -m 0644 src/main/sh/etc/systemd/system/%{unit} %{buildroot}%{smi}/etc/systemd/system/
ln -s %{smi}/etc/systemd/system/%{unit} %{buildroot}%{_sysconfdir}/systemd/system/%{unit}

%post
systemctl daemon-reload || :
for app in %{services}; do
    systemctl enable setmy-info-elixir@$app || :
    systemctl restart setmy-info-elixir@$app || :
done

%preun
if [ $1 -eq 0 ]; then
    for app in %{services}; do
        systemctl disable --now setmy-info-elixir@$app || :
    done
fi

%postun
systemctl daemon-reload || :

%files
%{lib}/modules
%{lib}/config
%{lib}/LICENSE
%{smi}/bin/smi-elixir-start
%{smi}/bin/smi-demo-module-a
%config(noreplace) %{smi}/etc/elixir/elixir.env
%config(noreplace) %{smi}/etc/elixir/machine.env
%{smi}/etc/systemd/system/%{unit}
%{_sysconfdir}/systemd/system/%{unit}
%dir %attr(0750,microservice,microservice) /var/opt/setmy.info/elixir
%dir %attr(0750,microservice,microservice) /var/opt/setmy.info/elixir/tmp

%changelog
* Wed Nov 11 2026 Imre Tabur <imre.tabur@mail.ee> - 0.1.0-1
- First package: the compiled apps, their service template and a CLI tool
