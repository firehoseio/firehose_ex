import subprocess

from checks import AgentCheck
from hashlib import md5

class DockerContainersCheck(AgentCheck):
    def check(self, instance):
        container_name = instance.get('container_name')
        output = subprocess.check_output("docker ps | grep -c -e '%s' || true" % container_name, shell=True)
        count = int(output)
        self.gauge('docker.running_containers', count, tags=["container_type:%s" % container_name])
