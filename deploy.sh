language: node_js
sudo: required
node_js:
- lts/*

cache:
  directories:
  - node_modules
script:
- "./deploy.sh"
branch: master
