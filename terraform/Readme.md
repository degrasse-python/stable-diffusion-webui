# Stable Diffusion deployed to AWS using Terraform Cloud

The automatic1111 architecture is fairly simple. It's built with Gradio and just 
needs to be deployed with basic auth for use. If you need multiuser access then you may need an auth application layer between sd webui and the internet. There are examples that use flask for a simple auth app that handles the login process. In this case we are just using the gradio apps built in auth that you can set with a base admin basic auth. In a future pull request I will use an auth app layer to show how you can use a simple database with user data for auth. Below is the application without the auth app layer between sd webui and the internet allowing for a private server that cannot be accessed by anyone that doesn't have the admin password.

![Solutions Reference](github.com/degrasse-python/stable-diffusion-webui/terraform/figs/sd-webui.png)

## Relevant Documentation
[For any questions about Terraform Cloud please check the TF Cloud docs](https://developer.hashicorp.com/terraform?ajs_aid=d07fb086-8fa2-4108-9d47-a886dd3a6017&product_intent=terraform)

[For any questions about deploying the Gradio app please check the gradio docs](https://www.gradio.app/guides/sharing-your-app)

[For any questions about Automatic111 Stable Diffusion](https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Features)

