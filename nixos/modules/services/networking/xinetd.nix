{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let

  cfg = config.services.xinetd;

  configFile = pkgs.writeText "xinetd.conf" ''
    defaults
    {
      log_type       = SYSLOG daemon info
      log_on_failure = HOST
      log_on_success = PID HOST DURATION EXIT
      ${cfg.extraDefaults}
    }

    ${concatMapStrings makeService cfg.services}
  '';

  makeService = srv: ''
    service ${srv.name}
    {
      protocol    = ${srv.protocol}
      ${optionalString srv.unlisted "type        = UNLISTED"}
      ${optionalString (srv.flags != "") "flags = ${srv.flags}"}
      socket_type = ${if srv.protocol == "udp" then "dgram" else "stream"}
      ${optionalString (srv.port != 0) "port        = ${toString srv.port}"}
      wait        = ${if srv.protocol == "udp" then "yes" else "no"}
      user        = ${srv.user}
      server      = ${srv.server}
      ${optionalString (srv.serverArgs != "") "server_args = ${srv.serverArgs}"}
      ${srv.extraConfig}
    }
  '';

in

{

  ###### interface

  options = {

    services.xinetd.enable = mkEnableOption "the xinetd super-server daemon";

    services.xinetd.extraDefaults = mkOption {
      default = "";
      type = types.lines;
      description = ''
        Additional configuration lines added to the default section of xinetd's configuration.
      '';
    };

    services.xinetd.services = mkOption {
      default = [ ];
      description = ''
        A list of services provided by xinetd.
      '';

      type =
        with types;
        listOf (submodule ({

          options = {

            name = mkOption {
              type = types.str;
              example = "login";
              description = "Name of the service.";
            };

            protocol = mkOption {
              type = types.str;
              default = "tcp";
              description = "Protocol of the service.  Usually `tcp` or `udp`.";
            };

            port = mkOption {
              type = types.port;
              default = 0;
              example = 123;
              description = "Port number of the service.";
            };

            user = mkOption {
              type = types.str;
              default = "nobody";
              description = "User account for the service";
            };

            server = mkOption {
              type = types.str;
              example = "/foo/bin/ftpd";
              description = "Path of the program that implements the service.";
            };

            serverArgs = mkOption {
              type = types.separatedString " ";
              default = "";
              description = "Command-line arguments for the server program.";
            };

            flags = mkOption {
              type = types.str;
              default = "";
              description = "";
            };

            unlisted = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Whether this server is listed in
                {file}`/etc/services`.  If so, the port
                number can be omitted.
              '';
            };

            extraConfig = mkOption {
              type = types.lines;
              default = "";
              description = "Extra configuration-lines added to the section of the service.";
            };

          };

        }));

    };

  };

  ###### implementation

  config = mkIf cfg.enable {
    systemd.services.xinetd = {
      description = "xinetd server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.xinetd ];
      script = "exec xinetd -syslog daemon -dontfork -stayalive -f ${configFile}";
    };
  };
}
