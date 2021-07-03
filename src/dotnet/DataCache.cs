using System;
using System.Collections.Generic;

namespace StreamXRef
{
    public class DataCache
    {
        public string ApiKey { get; set; }
        public Dictionary<String, Int32> UserInfoCache { get; set; }
        public Dictionary<String, ClipObject> ClipInfoCache { get; set; }
        public Dictionary<Int64, DateTime> VideoInfoCache { get; set; }

        public int GetTotalCount() => UserInfoCache.Count + ClipInfoCache.Count + VideoInfoCache.Count;

        public DataCache()
        {
            ApiKey = "";
            UserInfoCache = new Dictionary<String, Int32>(StringComparer.OrdinalIgnoreCase);
            ClipInfoCache = new Dictionary<String, ClipObject>(StringComparer.OrdinalIgnoreCase);
            VideoInfoCache = new Dictionary<Int64, DateTime>();
        }
    }

    public class ClipObject
    {
        public int Offset { get; set; }
        public Int64 VideoID { get; set; }
        public DateTime Created { get; set; }
        public Dictionary<String, String> Mapping { get; set; }

        public ClipObject()
        {
            Mapping = new Dictionary<String, String>(StringComparer.OrdinalIgnoreCase);
        }
    }
}
