local storage() = {
  volumeClaimTemplate: {
    apiVersion: 'v1',
    kind: 'PersistentVolumeClaim',
    spec: {
      accessModes: ['ReadWriteOnce'],
      resources: {
        requests: {
          storage: '16Gi',
        },
      },
      storageClassName: 'local-storage',
    },
  },
};

local kp =
  (import 'kube-prometheus/main.libsonnet') +
  (import 'kube-prometheus/addons/all-namespaces.libsonnet') +
  (import 'kube-prometheus/addons/anti-affinity.libsonnet') +
  //(import 'kube-prometheus/addons/custom-metrics.libsonnet') +
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
      prometheus+: {
        spec+: {
          externalUrl: 'https://prometheus.localhost',
          ruleSelector: {},
          retention: '30d',
          replicas: 1,
          storage: storage(),
        },
      },
    },
    alertmanager+:: {
      alertmanager+: {
        spec+: {
          externalUrl: 'https://alertmanager.localhost',
          replicas: 1,
          storage: storage(),
        },
      },
    },
    grafana+:: {
      deployment+: {
        spec+: {
          strategy: {
            type: 'Recreate',
          },
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
    },
    prometheusAdapter+: {
      deployment+: {
        spec+: {
          replicas: 1,
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
