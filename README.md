# infra_progress
for demo purposes

notes:
- Ideally, the code should look like what I wrote on the ideal.tf file but since I ran into errors when I ran terraform apply, I modified it to main.tf
- Also I just realized on main.tf I forgot to associate the second private subnet to the nat instance, please refer to my ideal.tf file for that
- To fix the errors I mentioned on the first bullet point, I put one resource at a time and hit terraform apply everytime I add a resource. Whenever the resource got added, terraform would present you the id of that resource that just got created. I then grab that id and use it for the following resource and repeat this process until I created all of the needed resources. This definitely is not the right way to do it but this is my temporary fix for now. I will look more into it and do more investigation on why refferencing with .id isn't working


my to do list for next week:
- Just in case for demo, prepare the infrastructure using sandbox too as a backup material
- Use the subnets calculated by misak
- Incorporate ELB 
- play around adding more AZ
- Investigate more into why the .id property isn't working
- consult with Lisa for feedback
