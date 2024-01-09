local kp =
  (import 'kube-prometheus/main.libsonnet') +
  (import 'kube-prometheus/addons/all-namespaces.libsonnet') +
  (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  // (import 'kube-prometheus/addons/custom-metrics.libsonnet') +
  (import 'kube-prometheus/addons/external-metrics.libsonnet') +
  (import 'kube-prometheus/addons/networkpolicies-disabled.libsonnet') +
  (import 'kube-prometheus/platforms/kubeadm.libsonnet') +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
        images: {
          alertmanager: 'quay.io/prometheus/alertmanager:v' + $.values.common.versions.alertmanager,
          blackboxExporter: 'quay.io/prometheus/blackbox-exporter:v' + $.values.common.versions.blackboxExporter,
          grafana: 'grafana/grafana:' + $.values.common.versions.grafana,
          kubeStateMetrics: 'registry.k8s.io/kube-state-metrics/kube-state-metrics:v' + $.values.common.versions.kubeStateMetrics,
          nodeExporter: 'quay.io/prometheus/node-exporter:v' + $.values.common.versions.nodeExporter,
          prometheus: 'quay.io/prometheus/prometheus:v' + $.values.common.versions.prometheus,
          prometheusAdapter: 'registry.k8s.io/prometheus-adapter/prometheus-adapter:v' + $.values.common.versions.prometheusAdapter,
          prometheusOperator: 'quay.io/prometheus-operator/prometheus-operator:v' + $.values.common.versions.prometheusOperator,
          prometheusOperatorReloader: 'quay.io/prometheus-operator/prometheus-config-reloader:v' + $.values.common.versions.prometheusOperator,
          kubeRbacProxy: 'quay.io/brancz/kube-rbac-proxy:v' + $.values.common.versions.kubeRbacProxy,
          configmapReload: 'jimmidyson/configmap-reload:v' + $.values.common.versions.configmapReload,
        },
      },
      prometheus+: {
        namespaces: [],
      },
      grafana+: {
        config+: {
          sections+: {
            server+: {
              root_url: 'https://grafana.localhost',
            },
          },
        },
      },
    },
    prometheusAdapter+: {
      deployment+: {
        spec+: {
          replicas: 1,
        },
      },
    },
    prometheus+:: {
      prometheus+: {
        spec+: {
          externalUrl: 'https://prometheus.localhost',
          ruleSelector: {},
          retention: '30d',
          replicas: 1,
          securityContext: {
            runAsUser: 0,
            runAsNonRoot: false,
            fsGroup: 0,
          },
          storage: {
            volumeClaimTemplate: {
              spec: {
                accessModes: ['ReadWriteOnce'],
                resources: { requests: { storage: '32Gi' } },
              },
            },
          },
        },
      },
      persistentVolume: {
        kind: 'PersistentVolume',
        apiVersion: 'v1',
        metadata: {
          name: 'prometheus-k8s-db-prometheus-k8s-0',
        },
        spec: {
          capacity: {
            storage: '32Gi',
          },
          hostPath: {
            path: '/mnt/kubernetes/prometheus/data0',
          },
          accessModes: ['ReadWriteOnce'],
          nodeAffinity: {
            required: {
              nodeSelectorTerms: [{
                matchExpressions: [{
                  key: 'kubernetes.io/hostname',
                  operator: 'In',
                  values: ['ubuntu'],
                }],
              }],
            },
          },
          claimRef: {
            kind: 'PersistentVolumeClaim',
            namespace: $.values.common.namespace,
            name: 'prometheus-k8s-db-prometheus-k8s-0',
            apiVersion: 'v1',
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
    },
    grafana+:: {
      deployment+: {
        spec+: {
          strategy: {
            type: 'RollingUpdate',
            rollingUpdate: {
              maxUnavailable: 1,
              maxSurge: 1
            }
          },
          template+: {
            spec+: {
              securityContext: {
                runAsUser: 0,
                runAsNonRoot: false,
                fsGroup: 0,
              },
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
      persistentVolume: {
        kind: 'PersistentVolume',
        apiVersion: 'v1',
        metadata: {
          name: 'grafana-storage',
        },
        spec: {
          capacity: {
            storage: '16Gi',
          },
          hostPath: {
            path: '/mnt/kubernetes/grafana/data',
          },
          accessModes: ['ReadWriteOnce'],
          nodeAffinity: {
            required: {
              nodeSelectorTerms: [{
                matchExpressions: [{
                  key: 'kubernetes.io/hostname',
                  operator: 'In',
                  values: ['ubuntu'],
                }],
              }],
            },
          },
          claimRef: {
            kind: 'PersistentVolumeClaim',
            namespace: $.values.common.namespace,
            name: 'grafana-storage',
            apiVersion: 'v1',
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
        },
      },
    },
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          externalUrl: 'https://alertmanager.localhost',
          replicas: 1,
          securityContext: {
            runAsUser: 0,
            runAsNonRoot: false,
            fsGroup: 0,
          },
          storage: {
            volumeClaimTemplate: {
              spec: {
                accessModes: ['ReadWriteOnce'],
                resources: { requests: { storage: '16Gi' } },
              },
            },
          },
        },
      },
      persistentVolume: {
        kind: 'PersistentVolume',
        apiVersion: 'v1',
        metadata: {
          name: 'alertmanager-main-db-alertmanager-main-0',
        },
        spec: {
          capacity: {
            storage: '16Gi',
          },
          hostPath: {
            path: '/mnt/kubernetes/alertmanager/data0',
          },
          accessModes: ['ReadWriteOnce'],
          nodeAffinity: {
            required: {
              nodeSelectorTerms: [{
                matchExpressions: [{
                  key: 'kubernetes.io/hostname',
                  operator: 'In',
                  values: ['ubuntu'],
                }],
              }],
            },
          },
          claimRef: {
            kind: 'PersistentVolumeClaim',
            namespace: $.values.common.namespace,
            name: 'alertmanager-main-db-alertmanager-main-0',
            apiVersion: 'v1',
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
    },
  };

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// { 'setup/pyrra-slo-CustomResourceDefinition': kp.pyrra.crd } +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
// { ['pyrra-' + name]: kp.pyrra[name] for name in std.objectFields(kp.pyrra) if name != 'crd' } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
