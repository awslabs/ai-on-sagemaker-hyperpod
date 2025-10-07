---
title : "FSx for Lustre compression"
weight : 63
---

This section will enable data compression for the Amazon FSx for Lustre file system.

You can use the Lustre data compression feature to achieve cost savings on your high-performance Amazon FSx for Lustre file systems and backup storage. When data compression is enabled, Amazon FSx for Lustre automatically compresses newly written files before they are written to disk and automatically uncompresses them when they are read.

Data compression uses the LZ4 algorithm, which is optimized to deliver high levels of compression without adversely impacting file system performance. LZ4 is a Lustre community-trusted and performance-oriented algorithm that provides a balance between compression speed and compressed file size.

Data compression reduces the amount of data that is transferred between Amazon FSx for Lustre file servers and storage. If you are not already using compressed file formats, you will see an increase in overall file system throughput capacity when using data compression.

1. Navigate back to the [Amazon FSx console.](https://us-west-2.console.aws.amazon.com/fsx)
2. In the Summary section, click the Update button next to Data compression type.

    ![Fsx comp test1](/img/03-advanced/comp1.png)

3. From the Select a new data compression type dropdown menu, select LZ4 then click Update.

    ![Fsx comp test2](/img/03-advanced/comp2.png)

4. Refresh the browser window a few times. The Lifecycle state should be Updating and the Data compression type should be None (Updating to LZ4).

    ![Fsx comp test3](/img/03-advanced/comp3.png)

5. Wait ~1 minute then refresh the browser window. The Lifecycle state should be Available and the Data compression type should be LZ4.

    ![Fsx comp test4](/img/03-advanced/comp4.png)

:::danger
Wait until the Data compression type is LZ4 before continuing.
:::