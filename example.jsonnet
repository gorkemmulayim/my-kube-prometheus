local kp =
  (import 'kube-prometheus/main.libsonnet') +
  (import 'kube-prometheus/addons/all-namespaces.libsonnet') +
  (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  (import 'kube-prometheus/addons/custom-metrics.libsonnet') +
  (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  (import 'kube-prometheus/platforms/kubeadm.libsonnet') +
  (import 'kube-prometheus/addons/weave-net/weave-net.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
      grafana+:: {
        config+: {
          sections+: {
            server+: {
              root_url: 'https://grafana.localhost',
            },
          },
        },
      },
    },
    prometheus+:: {
      namespaces: [],
      prometheus+: {
        spec+: {
          externalUrl: 'https://prometheus.localhost',
          ruleSelector: {},
          retention: '30d',
          replicas: 1,
          storage: {
            volumeClaimTemplate: {
              spec: {
                accessModes: ['ReadWriteOnce'],
                resources: { requests: { storage: '32Gi' } },
                storageClassName: 'rook-ceph-block',
              },
            },
          },
        },
      },
      ingress: {
        kind: 'Ingress',
        apiVersion: 'networking.k8s.io/v1',
        metadata: {
          name: 'prometheus-k8s',
          namespace: $.values.common.namespace,
          annotations: {
            'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
          },
        },
        spec: {
          ingressClassName: 'nginx',
          rules: [{
            host: 'prometheus.localhost',
            http: {
              paths: [{
                path: '/',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: 'prometheus-k8s',
                    port: {
                      name: 'web',
                    },
                  },
                },
              }],
            },
          }],
        },
      },
      virtualService: {
        kind: 'VirtualService',
        apiVersion: 'networking.istio.io/v1beta1',
        metadata: {
          name: 'prometheus-k8s',
          namespace: $.values.common.namespace,
        },
        spec: {
          hosts: ['prometheus.localhost'],
          gateways: ['istio-system/default-gateway'],
          http: [{
            match: [{
              uri: [{
                prefix: '/',
              }],
            }],
            route: [{
              destination: {
                host: 'prometheus-k8s',
                port: 'web',
              },
            }],
          }],
        },
      },
    },
    grafana+:: {
      deployment+: {
        spec+: {
          template+: {
            spec+: {
            volumes:
              std.map(
                function(v)
                  if v.name == 'grafana-storage' then {
                    'name':'grafana-storage',
                    'persistentVolumeClaim': {
                      'claimName': 'grafana-storage',
                    }
                  }
                  else
                    v,
              super.volumes,
              ),
            },
          },
        },
      },
      ingress: {
        kind: 'Ingress',
        apiVersion: 'networking.k8s.io/v1',
        metadata: {
          name: 'grafana',
          namespace: $.values.common.namespace,
          annotations: {
            'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
          },
        },
        spec: {
          ingressClassName: 'nginx',
          rules: [{
            host: 'grafana.localhost',
            http: {
              paths: [{
                path: '/',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: 'grafana',
                    port: {
                      name: 'http',
                    },
                  },
                },
              }],
            },
          }],
        },
      },
      virtualService: {
        kind: 'VirtualService',
        apiVersion: 'networking.istio.io/v1beta1',
        metadata: {
          name: 'grafana',
          namespace: $.values.common.namespace,
        },
        spec: {
          hosts: ['grafana.localhost'],
          gateways: ['istio-system/default-gateway'],
          http: [{
            match: [{
              uri: [{
                prefix: '/',
              }],
            }],
            route: [{
              destination: {
                host: 'grafana',
                port: 'http',
              },
            }],
          }],
        },
      },
      persistentVolumeClaim: {
        kind: 'PersistentVolumeClaim',
        apiVersion: 'v1',
        metadata: {
          name: 'grafana-storage',
          namespace: $.values.common.namespace,
        },
        spec: {
          accessModes: ['ReadWriteOnce'],
          resources: {
            requests: {
              storage: '4Gi',
            },
          },
          storageClassName: 'rook-ceph-block',
        },
      },
    },
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          externalUrl: 'https://alertmanager.localhost',
          replicas: 1,
          storage: {
            volumeClaimTemplate: {
              spec: {
                accessModes: ['ReadWriteOnce'],
                resources: { requests: { storage: '16Gi' } },
                storageClassName: 'rook-ceph-block',
              },
            },
          },
        },
      },
      ingress: {
        kind: 'Ingress',
        apiVersion: 'networking.k8s.io/v1',
        metadata: {
          name: 'alertmanager-main',
          namespace: $.values.common.namespace,
          annotations: {
            'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
          },
        },
        spec: {
          ingressClassName: 'nginx',
          rules: [{
            host: 'alertmanager.localhost',
            http: {
              paths: [{
                path: '/',
                pathType: 'Prefix',
                backend: {
                  service: {
                    name: 'alertmanager-main',
                    port: {
                      name: 'web',
                    },
                  },
                },
              }],
            },
          }],
        },
      },
      virtualService: {
        kind: 'VirtualService',
        apiVersion: 'networking.istio.io/v1beta1',
        metadata: {
          name: 'alertmanager-main',
          namespace: $.values.common.namespace,
        },
        spec: {
          hosts: ['alertmanager.localhost'],
          gateways: ['istio-system/default-gateway'],
          http: [{
            match: [{
              uri: [{
                prefix: '/',
              }],
            }],
            route: [{
              destination: {
                host: 'alertmanager-main',
                port: 'web',
              },
            }],
          }],
        },
      },
    },
  };

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
