{ pkgs, ... }: let
  port = {
    value = 51820;
    __toString = self: toString(self.value);
  };
in {
  # Requires UDP port forwarding to be enabled on the gateway.
  # In OpenWRT:
  #   Network -> Firewall -> Port Forwards -> Add -> Protocol: UDP, External port: $port,
  #   Destination zone: unspecified / optional, Internal IP address: any / optional, Internal port: any.
  networking.firewall.allowedUDPPorts = [ port.value ];
  networking.wg-quick.interfaces = {
    wg0 = {
      address = [ "10.69.134.110/32" "fc00:bbbb:bbbb:bb01::6:866d/128" ];
      dns = [ "10.64.0.1" ];
      listenPort = port.value;
      privateKeyFile = "/etc/wireguard/private.key";
      peers = [
        {
          publicKey = "C3jAgPirUZG6sNYe4VuAgDEYunENUyG34X42y+SBngQ=";
          allowedIPs = [ "0.0.0.0/0" "::0/0" ];
          endpoint = "193.32.127.69:${port}";
          persistentKeepalive = 25;
        }
      ];
      postUp = ''
        # Mark packets on the wg0 interface.
        wg set wg0 fwmark 51820
        # Forbid anything that doesn't go through wg0 on IPv4 and IPv6.
        ${pkgs.iptables}/bin/iptables -A OUTPUT \
          ! -d 192.168.0.0/16 \
          ! -o wg0 \
          -m mark ! --mark $(wg show wg0 fwmark) \
          -m addrtype ! --dst-type LOCAL \
          -j REJECT
        ${pkgs.iptables}/bin/ip6tables -A OUTPUT \
          ! -o wg0 \
          -m mark ! --mark $(wg show wg0 fwmark) \
          -m addrtype ! --dst-type LOCAL \
          -j REJECT
      '';
      postDown = ''
        ${pkgs.iptables}/bin/iptables -D OUTPUT \
          ! -o wg0 \
          -m mark ! --mark $(wg show wg0 fwmark) \
          -m addrtype ! --dst-type LOCAL \
          -j REJECT
        ${pkgs.iptables}/bin/ip6tables -D OUTPUT \
          ! -o wg0 -m mark \
          ! --mark $(wg show wg0 fwmark) \
          -m addrtype ! --dst-type LOCAL \
          -j REJECT
      '';
    };
  };
}

# [1]: https://alberand.com/nixos-wireguard-vpn.html
