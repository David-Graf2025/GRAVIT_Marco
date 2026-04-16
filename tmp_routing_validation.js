fetch("http://127.0.0.1:3000/admin/api/tenant-routing", {
  method: "PUT",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    defaultTenantId: "gravit_default",
    manualTenantId: "tenant_does_not_exist",
    domainTenantMapping: {}
  })
})
  .then(async (res) => {
    console.log("status=" + res.status);
    console.log(await res.text());
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
