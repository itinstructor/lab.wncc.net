<%@ Page Language="C#" %>
<%@ Import Namespace="LabWnccNet" %>
<%@ Import Namespace="System.Threading.Tasks" %>
<script runat="server">
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.ContentType = "text/plain";
        try
        {
            string ipToCheck = Request.QueryString["ip"] ?? "8.8.8.8";
            var task = IPBlacklistChecker.IsBlacklistedAsync(ipToCheck);
            task.Wait();
            var result = task.Result;
            
            Response.Write("IP Blacklist Check Test\n");
            Response.Write("========================\n\n");
            Response.Write("IP: " + ipToCheck + "\n");
            Response.Write("IsBlacklisted: " + result.IsBlacklisted + "\n");
            Response.Write("Source: " + (result.Source ?? "none") + "\n");
            Response.Write("Confidence: " + result.Confidence + "%\n\n");
            Response.Write("Check logs folder for blacklist_checker.log\n");
        }
        catch (Exception ex)
        {
            Response.Write("ERROR: " + ex.Message + "\n");
            Response.Write("Stack: " + ex.StackTrace);
        }
    }
</script>
