#!/bin/bash

set -e  # Exit if any command fails

echo "🔧 Step 1: Running Terraform..."
cd terraform
terraform init -input=false
terraform apply -auto-approve

echo "🌐 Step 2: Fetching EC2 Elastic IP..."
EC2_IP=$(terraform output -raw public_ip)
cd ..

echo "📁 Step 3: Creating Ansible dynamic inventory..."
cat > inventory.json <<EOF
{
  "all": {
    "hosts": "$EC2_IP",
    "vars": {
      "ansible_user": "ubuntu",
      "ansible_ssh_private_key_file": "/Users/usf277/.ssh/ansible_key"
    }
  }
}
EOF

echo "🔁 Step 4: SSH into EC2 once (auto-login and exit)..."
ssh -o StrictHostKeyChecking=accept-new -i /Users/usf277/.ssh/ansible_key ubuntu@"$EC2_IP" "echo 'SSH connection established and exited.'"

echo "🚀 Step 5: Running Ansible Playbook..."
ansible-playbook -i inventory.json playbook.yml --private-key /Users/usf277/.ssh/ansible_key

echo "✅ Done: EC2 is provisioned and configured."
