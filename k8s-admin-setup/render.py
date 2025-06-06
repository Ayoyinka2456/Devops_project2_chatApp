from jinja2 import Environment, FileSystemLoader

# Read the counter value from counter.txt
with open('counter.txt') as f:
    counter = f.read().strip()

# Set up Jinja2 environment
env = Environment(loader=FileSystemLoader('.'))
template = env.get_template('chatApp_deployment.j2')

# Render the template
output = template.render(counter=counter)

# Write the rendered YAML to file
with open('chatApp_deployment.yml', 'w') as f:
    f.write(output)


# How to run j2 
# python3 render.py 3
# this creates the deployment.yml


# RUN below command
#kubectl apply -f chatApp_deployment.yml

