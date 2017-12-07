{
  Comment: "Automated hostname update",
  Changes: [
    {
      Action: "UPSERT",
      ResourceRecordSet: {
        Name: "\($hostname).\($domain)",
        Type: "A",
        TTL: 120,
        ResourceRecords: [{Value: $ipv4}]
      }
    },
    {
      Action: "UPSERT",
      ResourceRecordSet: {
        Name: "\($hostname).\($domain)",
        Type: "AAAA",
        TTL: 120,
        ResourceRecords: [{Value: $ipv6}]
      }
    }
  ]
}
