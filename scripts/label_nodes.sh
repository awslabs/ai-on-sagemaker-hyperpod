existing_label_key="node.kubernetes.io/instance-type"
new_label_key="nvidia.com/gpu.present"
new_label_value="true"

if [ ! -z "$1" ]; then
  existing_label_value="$1" 
  echo "Labeling nodes with instance type ${existing_label_value} ..." 
  nodes=$(kubectl get nodes -l $existing_label_key=$existing_label_value --no-headers | awk '{print $1}')
else 
  echo "Labeling all nodes ..."
  nodes=$(kubectl get nodes --no-headers | awk '{print $1}')
fi

for node in $nodes; do
  kubectl label node "$node" $new_label_key=$new_label_value
done