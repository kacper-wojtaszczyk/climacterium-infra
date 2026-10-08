controller:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi
  # Only the labeled node owns the routed ingress IP. The Kapsule image does not
  # run scw-net-reconfig, so attach the IP in the host network before nginx starts.
  # NodePort cannot expose standard ports 80/443 on Kapsule.
  kind: DaemonSet
  nodeSelector:
    ingress.buttprint.eu/active: "true"
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  extraInitContainers:
    - name: configure-ingress-ip
      image: busybox:1.37
      command:
        - sh
        - -ec
        - |
          ip -4 addr show dev enp0s1 | grep -Fq "inet ${ingress_ip}/32" || ip addr add ${ingress_ip}/32 dev enp0s1
      securityContext:
        runAsUser: 0
        runAsNonRoot: false
        allowPrivilegeEscalation: false
        capabilities:
          add: [NET_ADMIN]
  publishService:
    enabled: false
  extraArgs:
    publish-status-address: "${ingress_ip}"
  service:
    type: ClusterIP
  # With hostNetwork the admission endpoint is a node IP:8443; Kapsule's
  # control plane cannot reach it. Validate ingress manifests before apply.
  admissionWebhooks:
    enabled: false
  config:
    use-forwarded-headers: "false"
    proxy-read-timeout: "30"
    log-format-escape-json: "true"
    log-format-upstream: '{"time":"$time_iso8601","remote_addr":"$remote_addr","request_method":"$request_method","request_uri":"$request_uri","status":$status,"body_bytes_sent":$body_bytes_sent,"request_time":$request_time,"upstream_response_time":"$upstream_response_time","http_referer":"$http_referer","http_user_agent":"$http_user_agent"}'