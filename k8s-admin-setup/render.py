from jinja2 import Environment, FileSystemLoader

# Read the counter value from counter.txt
with open('TAG.txt') as f:
    counter = f.read().strip()

# Set up Jinja2 environment
env = Environment(loader=FileSystemLoader('.'))
template = env.get_template('deployment.j2')

# Render the template
output = template.render(TAG=TAG)

# Write the rendered YAML to file
with open('deployment.yml', 'w') as f:
    f.write(output)


# How to run j2 
# python3 render.py 3
# this creates the deployment.yml


# RUN below command
#kubectl apply -f deployment.yml

