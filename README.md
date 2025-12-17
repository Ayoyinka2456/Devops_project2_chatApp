# Real-Time Node.js Chat Application with Automated CI/CD on AWS

## 📌 Project Overview

This project demonstrates the deployment and automation of a **real-time chat application** built with **Node.js and Socket.IO**, hosted on **AWS infrastructure** and delivered using **CI/CD and configuration management best practices**. The solution reflects a production-style setup commonly used in enterprise and consulting environments.

The project focuses on **real-time communication, secure cloud networking, infrastructure automation, and continuous delivery**, making it a strong example of modern cloud and DevOps engineering fundamentals.

---

## 🎯 Project Objectives

* Deploy a real-time Node.js chat application using **Socket.IO**
* Host the application on **AWS EC2** with public internet access
* Configure **NGINX as a reverse proxy** for application traffic
* Secure the environment using AWS networking best practices
* Automate server configuration using **Ansible**
* Implement a **Jenkins CI/CD pipeline** for automated application delivery

---

## 🏗️ High-Level Architecture

* **AWS EC2** – Application hosting
* **NGINX** – Reverse proxy and traffic routing
* **Node.js & Socket.IO** – Real-time application layer
* **Ansible** – Configuration management and server automation
* **Jenkins** – Continuous Integration and Deployment
* **Elastic IP / Route 53** – Public access and DNS resolution

---

## ⚙️ Key Features

* Real-time, bidirectional communication using Socket.IO
* Secure and scalable deployment on AWS EC2
* NGINX reverse proxy for improved traffic management
* Automated EC2 configuration with reusable Ansible playbooks
* CI/CD pipeline triggered on code changes
* Rapid, repeatable deployments with minimal downtime

---

## 📂 Repository Structure (Simplified)

```
├── ansible/             # Ansible playbooks for EC2 configuration
├── jenkins/             # Jenkinsfile and pipeline configuration
├── nginx/               # NGINX configuration templates
├── app/                 # Node.js & Socket.IO application source code
├── scripts/             # Deployment and helper scripts
└── README.md
```

---

## 🚀 Deployment Summary

* The Node.js application is deployed on an **AWS EC2 instance**.
* **NGINX** is configured as a reverse proxy to forward HTTP/HTTPS traffic to the Node.js application.
* Public access is enabled via an **Elastic IP or Route 53 DNS record**.
* **AWS Security Groups** allow inbound traffic on ports **80 (HTTP)** and **443 (HTTPS)**.
* **Ansible** automates installation of Node.js, NGINX, and application dependencies.
* A **Jenkins CI/CD pipeline** automates application builds and deployments upon source code changes.

---

## ✅ Validation & Testing

* Verified successful deployment of the Node.js application
* Confirmed real-time messaging functionality using Socket.IO
* Validated external accessibility using the public DNS or Elastic IP
* Ensured NGINX correctly routes traffic to the application

---

## 🧠 Skills Demonstrated

* Cloud Infrastructure Deployment (AWS)
* Real-Time Application Hosting
* Configuration Management with Ansible
* CI/CD Pipeline Design with Jenkins
* Secure Networking and Reverse Proxy Configuration
* DevOps and Automation Best Practices

---

## 📎 Notes

This project was developed as a **hands-on demonstration of real-world DevOps workflows**, emphasizing automation, reliability, and maintainability. It is well-suited for entry-level to early-career roles in **Cloud Engineering, Infrastructure Engineering, and DevOps**.


================================================

Chat-App
Port: 3000 for preference (instead of 443- NGINX reverse proxy)
