using System;
using System.Collections.Generic;

namespace StreamXRef
{
    public class ClipObject
    {
        public int Offset { get; set; }
        public int VideoID { get; set; }
        public DateTime Created { get; set; }
        public Dictionary<String, String> Mapping { get; set; }

        public ClipObject()
        {
            Mapping = new Dictionary<String, String>(StringComparer.InvariantCultureIgnoreCase);
        }
    }

    public class DataCache
    {
        public string ApiKey { get; set; }
        public Dictionary<String, Int32> UserInfoCache { get; set; }
        public Dictionary<String, ClipObject> ClipInfoCache { get; set; }
        public Dictionary<Int32, DateTime> VideoInfoCache { get; set; }

        public int GetTotalCount() => UserInfoCache.Count + ClipInfoCache.Count + VideoInfoCache.Count;

        public DataCache()
        {
            ApiKey = "";
            UserInfoCache = new Dictionary<String, Int32>(StringComparer.InvariantCultureIgnoreCase);
            ClipInfoCache = new Dictionary<String, ClipObject>(StringComparer.InvariantCultureIgnoreCase);
            VideoInfoCache = new Dictionary<Int32, DateTime>();
        }
    }
}
